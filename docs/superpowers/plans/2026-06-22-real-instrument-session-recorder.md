# Real-Instrument Session Recorder — Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add a DEBUG-only on-device recorder that captures a real-instrument take through the existing mono path, writes a `Fixtures`-compatible Float32 WAV + a raw-readings CSV, and exports it for headless `Benchmark --fixtures` scoring.

**Architecture:** The engine *emits* the exact post-downmix mono blocks it already consumes (a DEBUG-only `AsyncStream`); the **app** *persists* them — no file I/O or networking enters `TunerEngine`. A platform-agnostic `SessionRecorder` builds the WAV+CSV; `LiveTunerModel` drives it; a `#if DEBUG` control in `LiveTunerScreen` records and exports. The whole capability is compiled out of release.

**Tech Stack:** Swift 5.9, Swift Concurrency (actors/AsyncStream), SwiftUI, Swift Testing (`@Test`/`#expect`). Reuses `Bench/Fixtures.swift` (WAV codec + `CaseRunner` scorer).

**Spec:** `docs/superpowers/specs/2026-06-22-real-instrument-session-recorder-design.md`

## Global Constraints

- **Platforms:** iOS 17.0 / macOS 14.0 floors; Swift 5.9. Single multiplatform target `LUMA`.
- **Everything recording-related is `#if DEBUG`** — engine emission, recorder, UI. The release binary must contain no recording API, no new Info.plist file-sharing keys, and an unchanged `PrivacyInfo.xcprivacy`.
- **`SessionRecorder`'s testable core is platform-agnostic (no UIKit)** — the `LUMATests` target runs on **macOS**. UIKit share-sheet export lives in the view layer under `#if os(iOS)`.
- **WAV:** mono **Float32** (WAV format 3) at the actual capture sample rate. Bit-exact round-trip. **No `max(-1,min(1,s))` clamp on the float write** (clamp stays on the 16-bit path only).
- **Filenames must parse via `Fixtures.parseTrueFrequency`** — `<label>_<trueHz>.wav` or `<note>.wav`. Lock mode pre-fills from the target's nominal Hz; auto/chromatic requires an explicit label.
- **CSV holds raw `PitchReading` values** (NOT clock-corrected, NOT lock-relative) so a live log reconciles with an offline replay.
- **The RT tap `AudioCapture.ingest` is unchanged.** No change to the live analysis path.
- **`rawSamples` is lossless** (`.unbounded` buffering, never `.bufferingNewest`). On stop: cancel the drain task; `setRecording(false)` stops the yield; the ~5 min soft cap bounds *both* the recorder array and the stream backlog.
- **Commit messages:** conventional-commits subject (shown per step) + end every message with the trailer `Co-Authored-By: Claude Opus 4.8 (1M context) <noreply@anthropic.com>`.
- **Branch:** all work on `feat/session-recorder` (already created).
- **Test commands:** package — `swift test --package-path Packages/TunerEngine`; app — `xcodegen generate && xcodebuild test -scheme LUMA -destination 'platform=macOS'`.

## File Structure

| File | Action | Responsibility |
|---|---|---|
| `Packages/TunerEngine/Sources/TunerEngine/Bench/Fixtures.swift` | Modify | Add `encodeWAVFloat32` (lossless, unclamped). |
| `Packages/TunerEngine/Tests/TunerEngineTests/SessionReplayTests.swift` | Create | Float32 round-trip + replay-determinism tests. |
| `Packages/TunerEngine/Sources/TunerEngine/TunerEngine.swift` | Modify | `#if DEBUG` `rawSamples` stream, `setRecording`, `captureSampleRate`, emit hook in `consume()`. |
| `Packages/TunerEngine/Tests/TunerEngineTests/RawSampleEmissionTests.swift` | Create | Emission gating + losslessness. |
| `App/Engine/SessionRecorder.swift` | Create | `#if DEBUG` platform-agnostic recorder: accumulate, peak/clip, soft cap, WAV/CSV builders, naming, write. |
| `LUMA/Tests/SessionRecorderTests.swift` | Create | Recorder pure-logic tests (macOS). |
| `App/Engine/LiveTunerModel.swift` | Modify | `#if DEBUG` wiring: own recorder, drain task, tee raw reading, metadata/name derivation, start/stop. |
| `LUMA/Tests/SessionRecordingWiringTests.swift` | Create | Name/metadata derivation tests (macOS). |
| `App/LiveTunerScreen.swift` | Modify | `#if DEBUG` record control + peak/clip meter + confirm/override sheet + `#if os(iOS)` share-sheet export. |

---

### Task 1: Float32 WAV codec + replay-determinism guard

**Files:**
- Modify: `Packages/TunerEngine/Sources/TunerEngine/Bench/Fixtures.swift` (add after `encodeWAV`, ~`:175`)
- Test: `Packages/TunerEngine/Tests/TunerEngineTests/SessionReplayTests.swift` (create)

**Interfaces:**
- Consumes: existing `Fixtures.decodeWAV(_:) -> (samples: [Float], sampleRate: Double)?`, `Synth.pure/harmonic`, `PitchPipeline(sampleRate:a4:method:targetNote:policy:).process(_:) -> [PitchReading]` (`PitchReading: Equatable`).
- Produces: `Fixtures.encodeWAVFloat32(_ samples: [Float], sampleRate: Double) -> Data`.

- [ ] **Step 1: Write the failing tests**

Create `Packages/TunerEngine/Tests/TunerEngineTests/SessionReplayTests.swift`:

```swift
import Testing
import Foundation
@testable import TunerEngine

/// Float32 fixture codec + the determinism property that makes a recorded WAV a
/// faithful replay of the live pipeline (spec §7).
@Suite struct SessionReplayTests {
    let fs = 48_000.0

    @Test func float32RoundTripIsBitExactIncludingOverUnity() {
        // A >1.0 sample proves the float path does NOT clamp (16-bit would).
        let s: [Float] = [0, 0.5, -0.5, 1.0, -1.0, 1.5, -1.5, 0.123456]
        let data = Fixtures.encodeWAVFloat32(s, sampleRate: fs)
        let decoded = Fixtures.decodeWAV(data)
        #expect(decoded != nil)
        #expect(decoded!.sampleRate == fs)
        #expect(decoded!.samples == s)            // exact, no quantisation, no clamp
    }

    @Test func twoFreshPipelinesAreDeterministic() {
        let s = Synth.harmonic(fundamental: 146.83, sampleRate: fs, seconds: 1.0)   // D3
        let a = PitchPipeline(sampleRate: fs, a4: 440, method: .mpm, targetNote: nil, policy: .guitar).process(s)
        let b = PitchPipeline(sampleRate: fs, a4: 440, method: .mpm, targetNote: nil, policy: .guitar).process(s)
        #expect(!a.isEmpty)
        #expect(a == b)
    }

    @Test func recordedFloat32ReplaysExactly() {
        let s = Synth.harmonic(fundamental: 110.0, sampleRate: fs, seconds: 1.0)    // A2
        let direct = PitchPipeline(sampleRate: fs, a4: 440, method: .mpm, targetNote: nil, policy: .guitar).process(s)
        let decoded = Fixtures.decodeWAV(Fixtures.encodeWAVFloat32(s, sampleRate: fs))!.samples
        let replayed = PitchPipeline(sampleRate: fs, a4: 440, method: .mpm, targetNote: nil, policy: .guitar).process(decoded)
        #expect(!direct.isEmpty)
        #expect(replayed == direct)
    }
}
```

- [ ] **Step 2: Run tests to verify they fail**

Run: `swift test --package-path Packages/TunerEngine --filter SessionReplayTests`
Expected: FAIL — compile error `type 'Fixtures' has no member 'encodeWAVFloat32'`.

- [ ] **Step 3: Implement `encodeWAVFloat32`**

In `Fixtures.swift`, immediately after the existing `encodeWAV(_:sampleRate:)` method:

```swift
    /// Encode mono `[Float]` as a **32-bit IEEE-float** WAV (format 3) — lossless and
    /// **unclamped** (float carries the full range), so a recorded fixture replays the
    /// live pipeline output bit-for-bit. The 16-bit `encodeWAV` clamps; this must not
    /// (clamping would break the bit-exact round-trip). Pairs with `decodeWAV`'s float path.
    public static func encodeWAVFloat32(_ samples: [Float], sampleRate: Double) -> Data {
        var d = Data()
        func a32(_ v: UInt32) { d.append(contentsOf: [UInt8(v & 0xFF), UInt8((v >> 8) & 0xFF), UInt8((v >> 16) & 0xFF), UInt8((v >> 24) & 0xFF)]) }
        func a16(_ v: UInt16) { d.append(contentsOf: [UInt8(v & 0xFF), UInt8((v >> 8) & 0xFF)]) }
        func ascii(_ s: String) { d.append(contentsOf: Array(s.utf8)) }
        let bytesPerSample: UInt32 = 4
        let dataBytes = UInt32(samples.count) * bytesPerSample
        ascii("RIFF"); a32(36 + dataBytes); ascii("WAVE")
        ascii("fmt "); a32(16); a16(3); a16(1); a32(UInt32(sampleRate))   // 3 = IEEE float, 1 channel
        a32(UInt32(sampleRate) * bytesPerSample); a16(UInt16(bytesPerSample)); a16(32)   // byteRate, blockAlign, bits
        ascii("data"); a32(dataBytes)
        for s in samples { a32(s.bitPattern) }                           // no clamp — lossless
        return d
    }
```

- [ ] **Step 4: Run tests to verify they pass**

Run: `swift test --package-path Packages/TunerEngine --filter SessionReplayTests`
Expected: PASS (3 tests). If `twoFreshPipelinesAreDeterministic` reports `a.isEmpty`, raise `seconds` to 1.5 — a 1 s tone must yield readings.

- [ ] **Step 5: Commit**

```bash
git add Packages/TunerEngine/Sources/TunerEngine/Bench/Fixtures.swift Packages/TunerEngine/Tests/TunerEngineTests/SessionReplayTests.swift
git commit  # feat(engine): Float32 fixture WAV codec + replay-determinism tests
```

---

### Task 2: Engine raw-sample emission (DEBUG-only)

**Files:**
- Modify: `Packages/TunerEngine/Sources/TunerEngine/TunerEngine.swift` (add a `#if DEBUG` section; one insert in `consume()` at `:190`)
- Test: `Packages/TunerEngine/Tests/TunerEngineTests/RawSampleEmissionTests.swift` (create)

**Interfaces:**
- Consumes: the existing `consume()` loop and its `samples = ring.read()`.
- Produces (all `#if DEBUG`): `TunerEngine.rawSamples: AsyncStream<[Float]>`, `func setRecording(_ on: Bool)`, `var captureSampleRate: Double`, `func emitRawForRecording(_ samples: [Float])` (internal — test seam).

- [ ] **Step 1: Write the failing tests**

Create `Packages/TunerEngine/Tests/TunerEngineTests/RawSampleEmissionTests.swift`:

```swift
import Testing
import Foundation
@testable import TunerEngine

/// The DEBUG-only raw-sample emission: gated by `setRecording`, lossless, and it
/// finishes cleanly so a draining `for await` ends (spec §4, §11).
@Suite struct RawSampleEmissionTests {

    @Test func gatedByRecordingFlagAndFinishesOnStop() async {
        let engine = TunerEngine()
        let stream = await engine.rawSamples            // registers the continuation now
        var received: [[Float]] = []
        let drain = Task { for await block in stream { received.append(block) } }

        await engine.emitRawForRecording([1, 2, 3])     // not recording → dropped
        await engine.setRecording(true)
        await engine.emitRawForRecording([4, 5, 6])
        await engine.emitRawForRecording([7, 8, 9])
        await engine.setRecording(false)                // finishes the stream
        await drain.value                               // ends because the stream finished

        #expect(received == [[4, 5, 6], [7, 8, 9]])
    }

    @Test func losslessUnderManyBlocks() async {
        let engine = TunerEngine()
        let stream = await engine.rawSamples
        var total = 0
        let drain = Task { for await block in stream { total += block.count } }
        await engine.setRecording(true)
        for _ in 0..<1000 { await engine.emitRawForRecording([0, 0, 0, 0]) }
        await engine.setRecording(false)
        await drain.value
        #expect(total == 4000)                          // no drops
    }
}
```

- [ ] **Step 2: Run tests to verify they fail**

Run: `swift test --package-path Packages/TunerEngine --filter RawSampleEmissionTests`
Expected: FAIL — compile error `value of type 'TunerEngine' has no member 'rawSamples'`.

- [ ] **Step 3: Add the `#if DEBUG` emission section**

In `TunerEngine.swift`, add inside the actor (e.g. after `removeContinuation(_:)` at `:60`):

```swift
    #if DEBUG
    // MARK: - Raw-sample recording (DEBUG-only; compiled out of release)

    private var isRecordingRaw = false
    private var rawContinuation: AsyncStream<[Float]>.Continuation?

    /// The exact post-downmix mono blocks the pipeline consumes, for the DEBUG-only
    /// session recorder. **Lossless** (`.unbounded`) — a dropped block corrupts the
    /// recorded WAV. Single consumer; minting replaces the prior continuation. No file
    /// I/O here — the app persists.
    public var rawSamples: AsyncStream<[Float]> {
        AsyncStream([Float].self, bufferingPolicy: .unbounded) { cont in
            rawContinuation = cont
            cont.onTermination = { [weak self] _ in Task { await self?.clearRawContinuation() } }
        }
    }
    private func clearRawContinuation() { rawContinuation = nil }

    /// Gate raw emission. `false` also finishes the stream so a draining `for await`
    /// ends cleanly (the app additionally cancels its drain task).
    public func setRecording(_ on: Bool) {
        isRecordingRaw = on
        if !on { rawContinuation?.finish(); rawContinuation = nil }
    }

    /// Actual hardware capture rate (for the recorder's WAV header).
    public var captureSampleRate: Double {
        #if canImport(AVFoundation)
        return capture?.sampleRate ?? 48_000
        #else
        return 48_000
        #endif
    }

    /// Emit one block if recording. Called from `consume()`; `internal` so the
    /// gating/losslessness is unit-testable without live capture.
    func emitRawForRecording(_ samples: [Float]) {
        guard isRecordingRaw, let rawContinuation else { return }
        rawContinuation.yield(samples)
    }
    #endif
```

- [ ] **Step 4: Emit from `consume()`**

In `consume()`, change the non-empty branch (`:190`) from:

```swift
                if !samples.isEmpty {
                    for reading in pipeline.process(samples) {
```

to:

```swift
                if !samples.isEmpty {
                    #if DEBUG
                    emitRawForRecording(samples)
                    #endif
                    for reading in pipeline.process(samples) {
```

- [ ] **Step 5: Run tests to verify they pass**

Run: `swift test --package-path Packages/TunerEngine --filter RawSampleEmissionTests`
Expected: PASS (2 tests).

- [ ] **Step 6: Full package suite stays green**

Run: `swift test --package-path Packages/TunerEngine`
Expected: PASS (all suites; 132 baseline + new).

- [ ] **Step 7: Commit**

```bash
git add Packages/TunerEngine/Sources/TunerEngine/TunerEngine.swift Packages/TunerEngine/Tests/TunerEngineTests/RawSampleEmissionTests.swift
git commit  # feat(engine): DEBUG-only raw-sample emission for the session recorder
```

---

### Task 3: `SessionRecorder` core (DEBUG-only, platform-agnostic)

**Files:**
- Create: `App/Engine/SessionRecorder.swift`
- Test: `LUMA/Tests/SessionRecorderTests.swift`

**Interfaces:**
- Consumes: `Fixtures.encodeWAVFloat32` (Task 1), `Fixtures.parseTrueFrequency`, `PitchReading`, `Note(midi:)`/`.name`/`.octave`/`.frequency(a4:)`.
- Produces: `SessionMetadata` struct; `SessionRecorder` with `init(sampleRate:maxSeconds:)`, `append(samples:)`, `append(reading:)`, `peak`, `clippedCount`, `capReached`, `sampleRate`, `wavData()`, `csv(metadata:)`, `static fixtureStem(targetNote:a4:override:)`, `write(stem:metadata:to:)`.

- [ ] **Step 1: Write the failing tests**

Create `LUMA/Tests/SessionRecorderTests.swift`:

```swift
import Testing
import Foundation
import TunerEngine
@testable import LUMA

#if DEBUG
@MainActor
@Suite struct SessionRecorderTests {
    let fs = 48_000.0

    @Test func peakAndClipTracking() {
        let r = SessionRecorder(sampleRate: fs)
        r.append(samples: [0.2, -0.4, 0.9])
        #expect(abs(r.peak - 0.9) < 1e-6)
        #expect(r.clippedCount == 0)
        r.append(samples: [1.0, -1.2, 0.1])          // two |s| >= 1
        #expect(r.clippedCount == 2)
        #expect(abs(r.peak - 1.2) < 1e-6)
    }

    @Test func softCapTripsAndStopsAccumulating() {
        let r = SessionRecorder(sampleRate: 10, maxSeconds: 1)   // cap = 10 samples
        r.append(samples: Array(repeating: 0.1, count: 8))
        #expect(!r.capReached)
        r.append(samples: Array(repeating: 0.1, count: 8))
        #expect(r.capReached)
        #expect(r.samples.count == 10)
        r.append(samples: [0.1])                                 // no-op after cap
        #expect(r.samples.count == 10)
    }

    @Test func lockModeStemPrefillsFromTarget() {
        let stem = SessionRecorder.fixtureStem(targetNote: Note(midi: 40), a4: 440, override: nil)  // E2
        #expect(stem == "E2_82.41")
        #expect(Fixtures.parseTrueFrequency(fileName: stem! + ".wav", a4: 440) != nil)
    }

    @Test func autoModeRequiresExplicitValidLabel() {
        #expect(SessionRecorder.fixtureStem(targetNote: nil, a4: 440, override: nil) == nil)
        #expect(SessionRecorder.fixtureStem(targetNote: nil, a4: 440, override: "lowB_30.87") == "lowB_30.87")
        #expect(SessionRecorder.fixtureStem(targetNote: nil, a4: 440, override: "garbage!") == nil)
    }

    @Test func csvHasMetadataHeaderAndRawRows() {
        let r = SessionRecorder(sampleRate: fs)
        r.append(reading: PitchReading(frequency: 82.41, note: Note(midi: 40), cents: 0.3,
                                       confidence: 0.95, phase: 0.1, timestamp: 1.5))
        let meta = SessionMetadata(instrument: "guitar", tuningId: "std", a4: 440, correctionFactor: 1.0,
                                   sampleRate: fs, deviceModel: "test", referenceNote: "E2",
                                   capturedAt: Date(timeIntervalSince1970: 0), appVersion: "1.0.0")
        let csv = r.csv(metadata: meta)
        #expect(csv.contains("# a4,440.0"))
        #expect(csv.contains("timestamp,frequency,note,cents,confidence,phase,inharmonicityB,precisionCents,isLockIntegrated"))
        #expect(csv.contains("1.5,82.41,E2,0.3,0.95,0.1,,,false"))
    }
}
#endif
```

- [ ] **Step 2: Run tests to verify they fail**

Run: `xcodegen generate && xcodebuild test -scheme LUMA -destination 'platform=macOS' -only-testing:LUMATests/SessionRecorderTests`
Expected: FAIL — `cannot find 'SessionRecorder' in scope`.

- [ ] **Step 3: Implement `SessionRecorder`**

Create `App/Engine/SessionRecorder.swift`:

```swift
import Foundation
import TunerEngine

#if DEBUG
/// Session context written into the CSV header — all known at record time.
struct SessionMetadata {
    var instrument: String
    var tuningId: String
    var a4: Double
    var correctionFactor: Double
    var sampleRate: Double
    var deviceModel: String
    var referenceNote: String
    var capturedAt: Date
    var appVersion: String
}

/// DEBUG-only recorder: accumulates the exact mono samples the pipeline consumed plus
/// the raw per-hop readings, and on stop writes a `Fixtures`-compatible Float32 WAV +
/// a readings CSV. Platform-agnostic (no UIKit) so the core unit-tests on macOS; the
/// iOS share-sheet export lives in the view layer. Spec §4/§5.
@MainActor
final class SessionRecorder {
    private(set) var samples: [Float] = []
    private(set) var readings: [PitchReading] = []
    private(set) var peak: Float = 0
    private(set) var clippedCount = 0
    private(set) var capReached = false

    let sampleRate: Double
    let maxSamples: Int          // ~5 min soft cap

    init(sampleRate: Double, maxSeconds: Double = 300) {
        self.sampleRate = sampleRate
        self.maxSamples = Int(sampleRate * maxSeconds)
    }

    /// Append one captured block; updates peak/clip; trips the cap (the caller stops
    /// the engine yield when `capReached`). No-op once capped.
    func append(samples block: [Float]) {
        guard !capReached else { return }
        for s in block {
            let a = abs(s)
            if a > peak { peak = a }
            if a >= 1.0 { clippedCount += 1 }
        }
        let room = maxSamples - samples.count
        if block.count >= room {
            samples.append(contentsOf: block.prefix(room))
            capReached = true
        } else {
            samples.append(contentsOf: block)
        }
    }

    func append(reading: PitchReading) {
        guard !capReached else { return }
        readings.append(reading)
    }

    // MARK: Pure builders (unit-tested)

    func wavData() -> Data { Fixtures.encodeWAVFloat32(samples, sampleRate: sampleRate) }

    /// `#`-commented metadata header + one **raw** reading row per hop.
    func csv(metadata m: SessionMetadata) -> String {
        var out = ""
        out += "# instrument,\(m.instrument)\n"
        out += "# tuningId,\(m.tuningId)\n"
        out += "# a4,\(m.a4)\n"
        out += "# correctionFactor,\(m.correctionFactor)\n"
        out += "# sampleRate,\(m.sampleRate)\n"
        out += "# deviceModel,\(m.deviceModel)\n"
        out += "# referenceNote,\(m.referenceNote)\n"
        out += "# capturedAt,\(ISO8601DateFormatter().string(from: m.capturedAt))\n"
        out += "# appVersion,\(m.appVersion)\n"
        out += "timestamp,frequency,note,cents,confidence,phase,inharmonicityB,precisionCents,isLockIntegrated\n"
        for r in readings {
            let b = r.inharmonicityB.map { String($0) } ?? ""
            let p = r.precisionCents.map { String($0) } ?? ""
            out += "\(r.timestamp),\(r.frequency),\(r.note.name)\(r.note.octave),\(r.cents),\(r.confidence),\(r.phase),\(b),\(p),\(r.isLockIntegrated)\n"
        }
        return out
    }

    /// Derive a `Fixtures`-parseable stem (no extension). An explicit `override` wins
    /// (validated). Else lock mode pre-fills `<note><octave>_<nominalHz>` from the
    /// target; auto/chromatic (no target) returns nil — true Hz is undefined there.
    static func fixtureStem(targetNote: Note?, a4: Double, override: String?) -> String? {
        if let o = override, !o.isEmpty {
            return Fixtures.parseTrueFrequency(fileName: o + ".wav", a4: a4) != nil ? o : nil
        }
        guard let t = targetNote else { return nil }
        let stem = "\(t.name)\(t.octave)_\(String(format: "%.2f", t.frequency(a4: a4)))"
        return Fixtures.parseTrueFrequency(fileName: stem + ".wav", a4: a4) != nil ? stem : nil
    }

    // MARK: I/O

    /// Write `<stem>.wav` + `<stem>.csv` into `directory`; returns the two URLs.
    func write(stem: String, metadata: SessionMetadata, to directory: URL) throws -> (wav: URL, csv: URL) {
        let wavURL = directory.appendingPathComponent(stem + ".wav")
        let csvURL = directory.appendingPathComponent(stem + ".csv")
        try wavData().write(to: wavURL)
        try Data(csv(metadata: metadata).utf8).write(to: csvURL)
        return (wavURL, csvURL)
    }
}
#endif
```

- [ ] **Step 4: Run tests to verify they pass**

Run: `xcodebuild test -scheme LUMA -destination 'platform=macOS' -only-testing:LUMATests/SessionRecorderTests`
Expected: PASS (5 tests).

- [ ] **Step 5: Commit**

```bash
git add App/Engine/SessionRecorder.swift LUMA/Tests/SessionRecorderTests.swift
git commit  # feat(app): DEBUG-only SessionRecorder core (WAV/CSV/naming/metering)
```

---

### Task 4: `LiveTunerModel` wiring (DEBUG-only)

**Files:**
- Modify: `App/Engine/LiveTunerModel.swift` (add a `#if DEBUG` section near `:78`; one tee line in `apply()` at `:280`)
- Test: `LUMA/Tests/SessionRecordingWiringTests.swift` (create)

**Interfaces:**
- Consumes: `engine.rawSamples` / `setRecording` / `captureSampleRate` (Task 2); `SessionRecorder`, `SessionMetadata` (Task 3); existing `targetNote`, `a4`, `instrument`, `tuning`, `correctionFactor`, `running`, `note`.
- Produces (all `#if DEBUG`): `isRecording`, `recordPeak`, `recordClips`, `func startRecording() async`, `func stopRecording(labelOverride:) -> (wav: URL, csv: URL)?`, `func currentFixtureStem(override:) -> String?`, `func currentMetadata() -> SessionMetadata`.

- [ ] **Step 1: Write the failing tests**

Create `LUMA/Tests/SessionRecordingWiringTests.swift`:

```swift
import Testing
import Foundation
import TunerEngine
@testable import LUMA

#if DEBUG
@MainActor
@Suite struct SessionRecordingWiringTests {
    init() {
        UserDefaults.standard.removeObject(forKey: "lastInstrument")
        UserDefaults.standard.removeObject(forKey: "lastTuningId")
    }

    @Test func stemUsesLockedTarget() {
        let model = LiveTunerModel()
        model.setMode(.lock)                       // auto-targets the lowest string
        let t = model.targetNote
        #expect(t != nil)
        #expect(model.currentFixtureStem(override: nil)
                == SessionRecorder.fixtureStem(targetNote: t, a4: model.a4, override: nil))
    }

    @Test func autoModeStemNeedsOverride() {
        let model = LiveTunerModel()
        model.setMode(.auto)
        #expect(model.currentFixtureStem(override: nil) == nil)
        #expect(model.currentFixtureStem(override: "E2") == "E2")
    }

    @Test func metadataReflectsModelState() {
        let model = LiveTunerModel()
        model.setInstrument(.bass)
        let m = model.currentMetadata()
        #expect(m.instrument == model.instrument.rawValue)
        #expect(m.a4 == model.a4)
        #expect(m.tuningId == model.tuning.id)
    }
}
#endif
```

- [ ] **Step 2: Run tests to verify they fail**

Run: `xcodebuild test -scheme LUMA -destination 'platform=macOS' -only-testing:LUMATests/SessionRecordingWiringTests`
Expected: FAIL — `value of type 'LiveTunerModel' has no member 'currentFixtureStem'`.

- [ ] **Step 3: Add the `#if DEBUG` wiring section**

In `LiveTunerModel.swift`, after the stored `@ObservationIgnored` properties (e.g. after `lockGate` at `:77`):

```swift
    #if DEBUG
    // MARK: - Session recording (DEBUG-only)
    @ObservationIgnored private var recorder: SessionRecorder?
    @ObservationIgnored private var recordDrain: Task<Void, Never>?
    private(set) var isRecording = false
    private(set) var recordPeak: Float = 0
    private(set) var recordClips = 0

    /// Begin capturing the live mono stream + raw readings. Requires `running`.
    func startRecording() async {
        guard running, recorder == nil else { return }
        let e = engine
        let rec = SessionRecorder(sampleRate: await e.captureSampleRate)
        recorder = rec
        recordPeak = 0; recordClips = 0
        isRecording = true
        await e.setRecording(true)
        let stream = await e.rawSamples
        recordDrain = Task { @MainActor [weak self] in
            for await block in stream {
                guard let self, let rec = self.recorder else { break }
                rec.append(samples: block)
                self.recordPeak = rec.peak
                self.recordClips = rec.clippedCount
                if rec.capReached {
                    await e.setRecording(false)
                    self.status = "Recording cap reached (5 min)"
                    break
                }
            }
        }
    }

    /// Stop and write the take. Returns the file URLs, or nil if unnameable / write fails.
    func stopRecording(labelOverride: String?) -> (wav: URL, csv: URL)? {
        guard let rec = recorder else { return nil }
        let e = engine
        recordDrain?.cancel(); recordDrain = nil       // the stream won't finish on its own
        Task { await e.setRecording(false) }
        isRecording = false
        defer { recorder = nil }
        guard let stem = SessionRecorder.fixtureStem(targetNote: targetNote, a4: a4, override: labelOverride) else {
            status = "Need a target string or an explicit label to name the take"
            return nil
        }
        let dir = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        do { return try rec.write(stem: stem, metadata: currentMetadata(), to: dir) }
        catch { status = "Write failed: \(error.localizedDescription)"; return nil }
    }

    func currentFixtureStem(override: String?) -> String? {
        SessionRecorder.fixtureStem(targetNote: targetNote, a4: a4, override: override)
    }

    func currentMetadata() -> SessionMetadata {
        SessionMetadata(
            instrument: instrument.rawValue, tuningId: tuning.id, a4: a4,
            correctionFactor: correctionFactor, sampleRate: recorder?.sampleRate ?? 48_000,
            deviceModel: Self.deviceModelString(), referenceNote: note,
            capturedAt: Date(), appVersion: Self.appVersion)
    }

    private static var appVersion: String {
        Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "?"
    }
    private static func deviceModelString() -> String {
        #if os(iOS)
        var sys = utsname(); uname(&sys)
        let id = Mirror(reflecting: sys.machine).children.reduce(into: "") { acc, e in
            if let c = e.value as? Int8, c != 0 { acc.unicodeScalars.append(UnicodeScalar(UInt8(c))) }
        }
        return id.isEmpty ? "iOS" : id
        #else
        return "macOS"
        #endif
    }
    #endif
```

- [ ] **Step 4: Tee the raw reading in `apply()`**

In `apply(_ r: PitchReading)`, at the end of the method (after `lastUpdate = Date()` at `:280`):

```swift
        lastUpdate = Date()
        #if DEBUG
        recorder?.append(reading: r)        // raw — uncorrected, not lock-relative (spec §5)
        #endif
```

- [ ] **Step 5: Run tests to verify they pass**

Run: `xcodebuild test -scheme LUMA -destination 'platform=macOS' -only-testing:LUMATests/SessionRecordingWiringTests`
Expected: PASS (3 tests).

- [ ] **Step 6: Commit**

```bash
git add App/Engine/LiveTunerModel.swift LUMA/Tests/SessionRecordingWiringTests.swift
git commit  # feat(app): wire SessionRecorder into LiveTunerModel (DEBUG-only)
```

---

### Task 5: DEBUG recorder UI + export

**Files:**
- Modify: `App/LiveTunerScreen.swift` (existing `#if DEBUG` block at `:247`)

**Interfaces:**
- Consumes: `model.running`, `model.isRecording`, `model.recordPeak`, `model.recordClips`, `model.startRecording()`, `model.stopRecording(labelOverride:)`, `model.currentFixtureStem(override:)`.
- Produces: a record control + peak/clip meter + confirm/override sheet + (`#if os(iOS)`) share-sheet export. No new public API.

- [ ] **Step 1: Add the recorder UI inside the existing `#if DEBUG`**

In `LiveTunerScreen.swift`, within the `#if DEBUG` region (`:247`), add a recorder control. Example (adapt to the surrounding view structure):

```swift
            // DEBUG-only real-instrument recorder (spec §4) — never in release.
            VStack(spacing: 8) {
                HStack {
                    Button(model.isRecording ? "Stop & Save" : "Record take") {
                        if model.isRecording {
                            pendingExport = model.stopRecording(labelOverride: nil)
                            showLabelSheet = (pendingExport == nil)   // unnameable → ask for a label
                        } else {
                            Task { await model.startRecording() }
                        }
                    }
                    .disabled(!model.running)
                    .tint(model.isRecording ? .red : .accentColor)

                    if model.isRecording {
                        // Peak meter + clip flag — AGC is off, so a hot DI can clip silently.
                        ProgressView(value: Double(min(model.recordPeak, 1)))
                            .frame(width: 80)
                        Text(model.recordClips > 0 ? "CLIP \(model.recordClips)" : "peak \(Int(model.recordPeak * 100))%")
                            .font(.caption.monospaced())
                            .foregroundStyle(model.recordClips > 0 ? .red : .secondary)
                    }
                }
            }
            .sheet(isPresented: $showLabelSheet) {
                LabelSheet(stem: model.currentFixtureStem(override: nil)) { label in
                    pendingExport = model.stopRecording(labelOverride: label)
                    showLabelSheet = false
                }
            }
            #if os(iOS)
            .sheet(item: $exportItem) { item in ShareSheet(urls: [item.wav, item.csv]) }
            .onChange(of: pendingExport?.wav) { _, _ in
                if let e = pendingExport { exportItem = ExportItem(wav: e.wav, csv: e.csv); pendingExport = nil }
            }
            #endif
```

Add the supporting state to the view (near its other `@State`):

```swift
    #if DEBUG
    @State private var showLabelSheet = false
    @State private var pendingExport: (wav: URL, csv: URL)?
    #if os(iOS)
    @State private var exportItem: ExportItem?
    #endif
    #endif
```

- [ ] **Step 2: Add the helper views (file-scope, `#if DEBUG`)**

At the bottom of `LiveTunerScreen.swift`:

```swift
#if DEBUG
/// Confirm/override the fixture label when auto-naming can't (auto mode / no target).
private struct LabelSheet: View {
    let stem: String?
    let onSave: (String?) -> Void
    @State private var label: String = ""
    @Environment(\.dismiss) private var dismiss
    var body: some View {
        NavigationStack {
            Form {
                if let stem { Text("Suggested: \(stem)").foregroundStyle(.secondary) }
                TextField("Label or <note> (e.g. E2 or lowB_30.87)", text: $label)
                    .autocorrectionDisabled()
            }
            .navigationTitle("Name the take")
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") { onSave(label.isEmpty ? nil : label) }
                }
                ToolbarItem(placement: .cancelAction) { Button("Cancel") { dismiss() } }
            }
        }
    }
}

#if os(iOS)
import UIKit
struct ExportItem: Identifiable { let id = UUID(); let wav: URL; let csv: URL }
/// Wraps `UIActivityViewController` — DEBUG-only, so no Files-app Info.plist keys ship.
struct ShareSheet: UIViewControllerRepresentable {
    let urls: [URL]
    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: urls, applicationActivities: nil)
    }
    func updateUIViewController(_ vc: UIActivityViewController, context: Context) {}
}
#endif
#endif
```

- [ ] **Step 3: Build both platforms (the UI's "test")**

Run:
```bash
xcodegen generate
xcodebuild build -scheme LUMA -destination 'generic/platform=iOS Simulator'
xcodebuild build -scheme LUMA -destination 'platform=macOS'
```
Expected: both BUILD SUCCEEDED. (macOS compiles the recorder/UI sans `#if os(iOS)` share sheet; iOS includes it.)

- [ ] **Step 4: Verify zero release surface**

Run:
```bash
xcodebuild build -scheme LUMA -configuration Release -destination 'generic/platform=iOS Simulator' \
  OTHER_SWIFT_FLAGS='-D RELEASE_AUDIT' 2>&1 | tail -5
grep -rn "rawSamples\|setRecording\|SessionRecorder" App Packages/TunerEngine/Sources | grep -v "#if DEBUG" | grep -v "//"
```
Expected: Release build succeeds; the `grep` shows every reference sits inside a `#if DEBUG` region (no release-visible recording symbols). Manually confirm no new keys were added to `App/Info.plist` or `App/PrivacyInfo.xcprivacy`.

- [ ] **Step 5: Commit**

```bash
git add App/LiveTunerScreen.swift
git commit  # feat(app): DEBUG recorder UI — record, peak/clip meter, label, share export
```

- [ ] **Step 6: Full app suite + manual device note**

Run: `xcodebuild test -scheme LUMA -destination 'platform=macOS'`
Expected: PASS (all `LUMATests`).

**Manual on-device (developer, hardware required — not CI):** with a passthrough strobe in the chain (spec §3), tune a string to 0.0¢, Record → play → Stop & Save, share the `.wav`+`.csv` to your Mac, drop the `.wav` in `docs/benchmarks/fixtures/`, run `swift run -c release --package-path Packages/TunerEngine Benchmark --fixtures docs/benchmarks/fixtures` and confirm a sane absolute cents number. Record the result in `docs/benchmarks/accuracy.md`.

---

## Self-Review

**1. Spec coverage:**
- §2 engine emission → Task 2. §2 codec → Task 1. §2 recorder/export → Tasks 3–5. ✓
- §3 verify-at-capture rig → Task 5 manual note (process, not code). ✓
- §4 components (all five rows) → Tasks 1–5; lossless `.unbounded` → Task 2; engine emits / app persists → Tasks 2–3. ✓
- §5 file/naming/CSV contract → Task 3 (`fixtureStem`, `csv`) + Task 4 (raw tee). ✓
- §6 privacy boundary → `#if DEBUG` throughout + Task 5 Step 4 audit. ✓
- §7 determinism + codec + pipeline-determinism + clip + regression → Task 1 + Task 3 (clip) + Steps running full suites. ✓
- §8 acceptance (1 release-absence, 2 scorable output, 3 tests green, 4 RT tap unchanged) → Task 5 Step 4, Task 5 Step 6 manual, all test steps, and no task touches `AudioCapture.ingest`. ✓
- §11 gotchas → drain cancel (Task 4 Step 3 `recordDrain?.cancel()`), bound both buffers (cap stops accumulation *and* calls `setRecording(false)`), no float clamp (Task 1 implementation + over-unity test). ✓

**2. Placeholder scan:** No TBD/TODO; every code step shows complete code; every run step has an exact command + expected result. ✓

**3. Type consistency:** `encodeWAVFloat32(_:sampleRate:)`, `decodeWAV → (samples:sampleRate:)`, `rawSamples`/`setRecording`/`captureSampleRate`/`emitRawForRecording`, `SessionRecorder.fixtureStem(targetNote:a4:override:)`, `append(samples:)`/`append(reading:)`, `currentFixtureStem`/`currentMetadata`/`startRecording`/`stopRecording(labelOverride:)` — names identical across the tasks that define and consume them. ✓

**Assumptions to verify during execution:** (a) `tuning.strings.first` is the lowest string (model comment at `LiveTunerScreen`/`LiveTunerModel.setMode` says so — the Task 4 test avoids hardcoding by comparing to `fixtureStem`); (b) the existing `#if DEBUG` block in `LiveTunerScreen.swift:247` is inside a `View` body where the snippet's modifiers attach cleanly — adapt placement to the actual surrounding view.
