# Instrument Profiles (Slice 1) Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Introduce a first-class `InstrumentProfile` and a per-instrument `DetectionPolicy`, consolidating LUMA's scattered band/gate/lock constants behind one typed source — without changing detection behavior (the bass *fix* is deferred).

**Architecture:** A 3-layer split that respects the package boundary (`TunerEngine` ⊥ `LumaDesignSystem`): `DetectionPolicy` (pure DSP) lives in `TunerEngine`; `Instrument`/`Tuning` stay in `LumaDesignSystem`; `InstrumentProfile` (the unifying composition) lives in the App layer, the only place allowed to import both. The pipeline's default policy is `.fullRange` (today's exact constants) so the benchmark and every existing test stay byte-identical; the app selects `.guitar`/`.bass`.

**Tech Stack:** Swift 5.9+, Swift Concurrency (`actor`/`async`), Swift Testing (`@Test`/`#expect`), Accelerate/vDSP, SwiftUI (`@Observable`/`@AppStorage`), XcodeGen.

**Spec:** `docs/superpowers/specs/2026-06-17-instrument-profiles-design.md`

---

## File Structure

**TunerEngine package (`Packages/TunerEngine/`):**
- Create `Sources/TunerEngine/DSP/DetectionPolicy.swift` — `BandSpec`, `DetectionPolicy`, helpers, `.fullRange`/`.guitar`/`.bass` presets.
- Modify `Sources/TunerEngine/DSP/PitchDetector.swift` — thread `emitFloor` through `detect`/`hybrid`.
- Modify `Sources/TunerEngine/DSP/Smoothing.swift` — `SustainGate.step` accepts a per-call `floor`.
- Modify `Sources/TunerEngine/Pipeline/PitchPipeline.swift` — own a `policy`; route `searchRange`, smoother, gate, `emitFloor`, and band selection through it; add a testable `nextBand`.
- Modify `Sources/TunerEngine/TunerEngine.swift` — stored `detectionPolicy` + `setDetectionPolicy`, pass to pipeline.
- Create `Tests/TunerEngineTests/DetectionPolicyTests.swift`.
- Modify `Tests/TunerEngineTests/PipelineTests.swift` — add band-sweep parity + clamp parity tests.

**App layer (`App/` + `LUMA/Tests/`):**
- Create `App/Engine/InstrumentProfile.swift` — the unifying type + built-in registry.
- Modify `App/Engine/PitchReadingStrobe.swift` — `strobeInput(minLockConfidence:)`; drop the hardcoded computed property.
- Modify `App/Engine/LiveTunerModel.swift` — hold a `profile`; push policy; persist + restore last-used instrument/tuning.
- Create `LUMA/Tests/InstrumentProfileTests.swift` and `LUMA/Tests/LiveTunerModelProfileTests.swift`.

---

## Phase A — TunerEngine (headless, `swift test`)

### Task 1: `DetectionPolicy` + `BandSpec` types and presets

**Files:**
- Create: `Packages/TunerEngine/Sources/TunerEngine/DSP/DetectionPolicy.swift`
- Test: `Packages/TunerEngine/Tests/TunerEngineTests/DetectionPolicyTests.swift`

- [ ] **Step 1: Write the failing test**

Create `Packages/TunerEngine/Tests/TunerEngineTests/DetectionPolicyTests.swift`:

```swift
import Foundation
import Testing
@testable import TunerEngine

@Suite struct DetectionPolicyTests {

    @Test func fullRangeMatchesLegacyConstants() {
        let p = DetectionPolicy.fullRange
        #expect(p.searchRange == PitchPipeline.searchRange)          // 27...1400
        #expect(p.smoothingAlpha == AnalysisConfig.smoothingAlpha)   // 0.35
        #expect(p.smoothingMedianCount == 5)
        #expect(p.emitFloor == AnalysisConfig.emitFloor)             // 0.5
        #expect(p.bands.map(\.label) == ["high", "mid", "low", "ultralow"])
        #expect(p.bands[0].window == 1024 && p.bands[0].hop == 256)
        #expect(p.bands[3].window == 8192 && p.bands[3].hop == 2048)
    }

    @Test func searchRangesPerProfile() {
        #expect(DetectionPolicy.guitar.searchRange == 60...1400)
        #expect(DetectionPolicy.bass.searchRange == 25...420)
    }

    @Test func bandLookupByFrequency() {
        let p = DetectionPolicy.fullRange
        #expect(p.band(forFrequency: 300).label == "high")
        #expect(p.band(forFrequency: 150).label == "mid")
        #expect(p.band(forFrequency: 80).label == "low")
        #expect(p.band(forFrequency: 31).label == "ultralow")
    }

    @Test func confidenceFloorsMatchLegacySplit() {
        let p = DetectionPolicy.fullRange
        // Lock floor: 0.75 below 120 Hz, 0.90 at/above (former minLockConfidence).
        #expect(p.lockConfidence(forFrequency: 80) == 0.75)
        #expect(p.lockConfidence(forFrequency: 120) == 0.90)
        #expect(p.lockConfidence(forFrequency: 300) == 0.90)
        // Sustain floor: uniform 0.6 across all bands (former sustainMinConfidence).
        #expect(p.sustainConfidence(forFrequency: 31) == 0.6)
        #expect(p.sustainConfidence(forFrequency: 300) == 0.6)
    }
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `swift test --package-path Packages/TunerEngine --filter DetectionPolicyTests`
Expected: FAIL — `cannot find 'DetectionPolicy' in scope`.

- [ ] **Step 3: Write the implementation**

Create `Packages/TunerEngine/Sources/TunerEngine/DSP/DetectionPolicy.swift`:

```swift
import Foundation

/// One entry in a `DetectionPolicy`'s adaptive-window plan: window/hop geometry
/// plus the per-band confidence floors. Bands are ordered high→low in a policy;
/// `floorHz` is the band's lower edge and `hysteresisHz` the anti-chatter margin
/// around it. (Consolidates the former scattered AnalysisConfig band/threshold
/// constants and the app-layer lock floors — docs/todos M2/M3/M7.)
public struct BandSpec: Sendable, Equatable {
    public var window: Int
    public var hop: Int
    public var floorHz: Double
    public var hysteresisHz: Double
    public var sustainConfidence: Double
    public var lockConfidence: Double
    public var label: String

    public init(window: Int, hop: Int, floorHz: Double, hysteresisHz: Double,
                sustainConfidence: Double, lockConfidence: Double, label: String) {
        self.window = window
        self.hop = hop
        self.floorHz = floorHz
        self.hysteresisHz = hysteresisHz
        self.sustainConfidence = sustainConfidence
        self.lockConfidence = lockConfidence
        self.label = label
    }
}

/// Per-instrument detection *policy* — the small set of knobs that vary by
/// instrument or are needed to fix bass settling. The pipeline reads these
/// instead of global constants. Universal constants (nsdfPeakK, octave guard,
/// lock-precision, snap) stay in code. Built-in profiles are code-defined and
/// nothing persists a policy, so it is intentionally not `Codable`.
public struct DetectionPolicy: Sendable, Equatable {
    public var searchRange: ClosedRange<Double>
    public var bands: [BandSpec]          // ordered high→low
    public var acquire: BandSpec          // cold-start window
    public var smoothingAlpha: Double
    public var smoothingMedianCount: Int
    public var emitFloor: Double

    public init(searchRange: ClosedRange<Double>, bands: [BandSpec], acquire: BandSpec,
                smoothingAlpha: Double, smoothingMedianCount: Int, emitFloor: Double) {
        self.searchRange = searchRange
        self.bands = bands
        self.acquire = acquire
        self.smoothingAlpha = smoothingAlpha
        self.smoothingMedianCount = smoothingMedianCount
        self.emitFloor = emitFloor
    }

    /// The band for a fundamental by **pure floor lookup** (no hysteresis) —
    /// matches the former `AnalysisConfig.band(forFrequency:)`. `bands` must be
    /// ordered high→low; returns the first whose `floorHz` ≤ f0, else the lowest.
    public func band(forFrequency f0: Double) -> BandSpec {
        for b in bands where f0 >= b.floorHz { return b }
        return bands.last ?? acquire
    }

    /// Per-band lock-confidence floor for a fundamental (pure lookup) — replaces
    /// the former app-layer `minLockConfidence`.
    public func lockConfidence(forFrequency f0: Double) -> Double {
        band(forFrequency: f0).lockConfidence
    }

    /// Per-band sustain floor for a fundamental (pure lookup).
    public func sustainConfidence(forFrequency f0: Double) -> Double {
        band(forFrequency: f0).sustainConfidence
    }

    /// Guitar bands/gates + the full 27…1400 range. The headless/benchmark
    /// default — references the legacy constants directly, so it is today's
    /// behavior by construction (zero-delta).
    public static let fullRange = DetectionPolicy(
        searchRange: PitchPipeline.searchRange,
        bands: [
            BandSpec(window: AnalysisConfig.high.window,     hop: AnalysisConfig.high.hop,
                     floorHz: AnalysisConfig.highMidHz,      hysteresisHz: AnalysisConfig.highMidHysteresis,
                     sustainConfidence: AnalysisConfig.sustainMinConfidence, lockConfidence: 0.90, label: "high"),
            BandSpec(window: AnalysisConfig.mid.window,      hop: AnalysisConfig.mid.hop,
                     floorHz: AnalysisConfig.midLowHz,       hysteresisHz: AnalysisConfig.midLowHysteresis,
                     sustainConfidence: AnalysisConfig.sustainMinConfidence, lockConfidence: 0.90, label: "mid"),
            BandSpec(window: AnalysisConfig.low.window,      hop: AnalysisConfig.low.hop,
                     floorHz: AnalysisConfig.lowUltraLowHz,  hysteresisHz: AnalysisConfig.lowUltraLowHysteresis,
                     sustainConfidence: AnalysisConfig.sustainMinConfidence, lockConfidence: 0.75, label: "low"),
            BandSpec(window: AnalysisConfig.ultraLow.window, hop: AnalysisConfig.ultraLow.hop,
                     floorHz: 0,                             hysteresisHz: 0,
                     sustainConfidence: AnalysisConfig.sustainMinConfidence, lockConfidence: 0.75, label: "ultralow"),
        ],
        acquire: BandSpec(window: AnalysisConfig.acquire.window, hop: AnalysisConfig.acquire.hop,
                          floorHz: 0, hysteresisHz: 0,
                          sustainConfidence: AnalysisConfig.sustainMinConfidence, lockConfidence: 0.75, label: "acquire"),
        smoothingAlpha: AnalysisConfig.smoothingAlpha,
        smoothingMedianCount: 5,
        emitFloor: AnalysisConfig.emitFloor
    )

    /// Guitar = `.fullRange` with the search floor clamped to ~60 Hz (below Drop C's
    /// C2 = 65.4 Hz) for octave-safety. Verified zero-delta vs `.fullRange` on
    /// guitar-range stimuli (Task 5).
    public static let guitar = DetectionPolicy(
        searchRange: 60...1400,
        bands: fullRange.bands, acquire: fullRange.acquire,
        smoothingAlpha: fullRange.smoothingAlpha, smoothingMedianCount: fullRange.smoothingMedianCount,
        emitFloor: fullRange.emitFloor
    )

    /// Bass — in Slice 1 identical to `.fullRange` except the search range (wide
    /// enough for A0 ≈ 27.5 Hz). Bands/gates are tuned in the deferred bass-fix
    /// (docs/todos/bass-detection-policy-tuning.md).
    public static let bass = DetectionPolicy(
        searchRange: 25...420,
        bands: fullRange.bands, acquire: fullRange.acquire,
        smoothingAlpha: fullRange.smoothingAlpha, smoothingMedianCount: fullRange.smoothingMedianCount,
        emitFloor: fullRange.emitFloor
    )
}
```

- [ ] **Step 4: Run test to verify it passes**

Run: `swift test --package-path Packages/TunerEngine --filter DetectionPolicyTests`
Expected: PASS (4 tests).

- [ ] **Step 5: Commit**

```bash
git add Packages/TunerEngine/Sources/TunerEngine/DSP/DetectionPolicy.swift \
        Packages/TunerEngine/Tests/TunerEngineTests/DetectionPolicyTests.swift
git commit -m "feat(dsp): add DetectionPolicy/BandSpec with fullRange/guitar/bass presets"
```

---

### Task 2: Thread `emitFloor` through `PitchDetector`

**Files:**
- Modify: `Packages/TunerEngine/Sources/TunerEngine/DSP/PitchDetector.swift:32-37` (detect signature), `:57-58` (hybrid call), `:160-178` (hybrid signature + use)
- Test: `Packages/TunerEngine/Tests/TunerEngineTests/DetectionPolicyTests.swift`

- [ ] **Step 1: Write the failing test** (append to `DetectionPolicyTests`)

```swift
    @Test func detectAcceptsEmitFloorAndDefaultsToLegacy() {
        // A clean A2 frame still detects with an explicit floor equal to the default.
        let frame = TestSupport.stringFrame(110, n: 4096)
        let a = PitchDetector.detect(frame, sampleRate: TestSupport.fs,
                                     range: 27...1400, method: .hybrid)
        let b = PitchDetector.detect(frame, sampleRate: TestSupport.fs,
                                     range: 27...1400, method: .hybrid, emitFloor: 0.5)
        #expect(a?.frequency == b?.frequency, "explicit default floor matches implicit default")
        #expect((b?.frequency ?? 0) > 0)
    }
```

- [ ] **Step 2: Run test to verify it fails**

Run: `swift test --package-path Packages/TunerEngine --filter detectAcceptsEmitFloor`
Expected: FAIL — `extra argument 'emitFloor' in call`.

- [ ] **Step 3: Write the implementation**

In `PitchDetector.swift`, change the `detect` signature (line 32-37) to add the parameter and forward it to `hybrid`:

```swift
    static func detect(
        _ frame: [Float],
        sampleRate: Double,
        range: ClosedRange<Double>,
        method: DetectionMethod,
        emitFloor: Double = AnalysisConfig.emitFloor
    ) -> DetectorResult? {
```

In the `switch method` block (line 57-58), pass it through:

```swift
        case .hybrid:
            return hybrid(corr, sampleRate: sampleRate, minLag: minLag, maxLag: maxLag, emitFloor: emitFloor)
```

Change the `hybrid` signature (line 160-165) and its octave-rescue line (line 177):

```swift
    static func hybrid(
        _ corr: Correlation,
        sampleRate: Double,
        minLag: Int,
        maxLag: Int,
        emitFloor: Double = AnalysisConfig.emitFloor
    ) -> DetectorResult? {
```

```swift
            let pick = lower.clarity > emitFloor ? lower : higher
```

- [ ] **Step 4: Run tests to verify they pass**

Run: `swift test --package-path Packages/TunerEngine --filter DetectionPolicyTests`
Run: `swift test --package-path Packages/TunerEngine --filter PitchDetectorTests`
Expected: PASS for both (the default keeps `PitchDetectorTests` green).

- [ ] **Step 5: Commit**

```bash
git add Packages/TunerEngine/Sources/TunerEngine/DSP/PitchDetector.swift \
        Packages/TunerEngine/Tests/TunerEngineTests/DetectionPolicyTests.swift
git commit -m "feat(dsp): thread emitFloor through PitchDetector (default = legacy 0.5)"
```

---

### Task 3: `SustainGate.step` accepts a per-call floor

**Files:**
- Modify: `Packages/TunerEngine/Sources/TunerEngine/DSP/Smoothing.swift:74-85`
- Test: `Packages/TunerEngine/Tests/TunerEngineTests/SmoothingTests.swift`

- [ ] **Step 1: Write the failing test** (append to the existing `SmoothingTests` suite — open the file and add inside the `@Suite struct`)

```swift
    @Test func sustainGateUsesPerCallFloor() {
        var gate = SustainGate(sustainFrames: 3)
        // confidence 0.7 passes a 0.6 floor but fails a 0.8 floor.
        #expect(gate.step(confidence: 0.7, floor: 0.6).emit == true)
        #expect(gate.step(confidence: 0.7, floor: 0.8).emit == false)
    }
```

- [ ] **Step 2: Run test to verify it fails**

Run: `swift test --package-path Packages/TunerEngine --filter sustainGateUsesPerCallFloor`
Expected: FAIL — `extra argument 'floor' in call`.

- [ ] **Step 3: Write the implementation**

In `Smoothing.swift`, replace the `SustainGate.step` method (line 77-85) with a per-call floor, keeping a back-compatible overload that uses the stored `minConfidence`:

```swift
    /// Returns whether to emit this frame and whether it's reached stable sustain.
    /// `floor` is the per-band confidence threshold (from the active `DetectionPolicy`).
    mutating func step(confidence: Double, floor: Double) -> (emit: Bool, stable: Bool) {
        if confidence >= floor {
            confidentStreak = min(confidentStreak + 1, sustainFrames * 4)
            return (true, confidentStreak >= sustainFrames)
        } else {
            confidentStreak = 0
            return (false, false)
        }
    }

    /// Back-compatible overload using the gate's configured `minConfidence`.
    mutating func step(confidence: Double) -> (emit: Bool, stable: Bool) {
        step(confidence: confidence, floor: minConfidence)
    }
```

- [ ] **Step 4: Run tests to verify they pass**

Run: `swift test --package-path Packages/TunerEngine --filter SmoothingTests`
Expected: PASS (existing tests still green via the overload; new test green).

- [ ] **Step 5: Commit**

```bash
git add Packages/TunerEngine/Sources/TunerEngine/DSP/Smoothing.swift \
        Packages/TunerEngine/Tests/TunerEngineTests/SmoothingTests.swift
git commit -m "feat(dsp): SustainGate.step accepts a per-band floor"
```

---

### Task 4: `PitchPipeline` honors the policy

**Files:**
- Modify: `Packages/TunerEngine/Sources/TunerEngine/Pipeline/PitchPipeline.swift` (init/fields `:18-69`, `analyze` gate `:112-114`, smoother/gate `:41-42`, `nextConfig` `:234,298-318`, `reset` `:93-99`)
- Test: `Packages/TunerEngine/Tests/TunerEngineTests/PipelineTests.swift`

- [ ] **Step 1: Write the failing test** (append to `PipelineTests`)

```swift
    @Test func nextBandReproducesLegacyTransitionsOnSweep() {
        let p = DetectionPolicy.fullRange
        func label(_ f0: Double, from: String) -> String {
            let cur = (p.bands.first { $0.label == from }) ?? p.acquire
            return PitchPipeline.nextBand(for: f0, current: cur, in: p).label
        }
        // Rising edges (band-above floor + hysteresis): 45 / 130 / 265.
        #expect(label(46, from: "ultralow") == "low")
        #expect(label(131, from: "low") == "mid")
        #expect(label(266, from: "mid") == "high")
        // Falling edges (current floor − hysteresis): 235 / 110 / 35.
        #expect(label(234, from: "high") == "mid")
        #expect(label(109, from: "mid") == "low")
        #expect(label(34, from: "low") == "ultralow")
        // Inside hysteresis → stays put (no chatter).
        #expect(label(250, from: "mid") == "mid")
        #expect(label(40, from: "low") == "low")
    }

    @Test func customBandPlanChangesChosenWindow() {
        // A one-band policy with a huge window proves the plumbing is live.
        let band = BandSpec(window: 16384, hop: 4096, floorHz: 0, hysteresisHz: 0,
                            sustainConfidence: 0.6, lockConfidence: 0.75, label: "only")
        let custom = DetectionPolicy(searchRange: 27...1400, bands: [band], acquire: band,
                                     smoothingAlpha: 0.35, smoothingMedianCount: 5, emitFloor: 0.5)
        #expect(PitchPipeline.nextBand(for: 200, current: band, in: custom).window == 16384)
    }
```

- [ ] **Step 2: Run test to verify it fails**

Run: `swift test --package-path Packages/TunerEngine --filter nextBandReproducesLegacy`
Expected: FAIL — `type 'PitchPipeline' has no member 'nextBand'`.

- [ ] **Step 3: Write the implementation**

In `PitchPipeline.swift`:

(a) Add the policy field and update the smoother/gate fields (replace lines 41-42 and add after `targetNote`):

```swift
    /// Active per-instrument detection policy (default = full-range = legacy).
    public var policy: DetectionPolicy
    private var smoother: FrequencySmoother
    private var gate = SustainGate()
```

(b) Update `init` (lines 57-69) to accept and apply the policy:

```swift
    public init(
        sampleRate: Double = 48_000,
        a4: Double = Pitch.standardA4,
        method: DetectionMethod = .mpm,
        targetNote: Note? = nil,
        policy: DetectionPolicy = .fullRange
    ) {
        self.sampleRate = sampleRate
        self.a4 = a4
        self.method = method
        self.targetNote = targetNote
        self.policy = policy
        self.preproc = Preprocessor(sampleRate: sampleRate)
        self.ring = [Float](repeating: 0, count: cap)
        self.smoother = FrequencySmoother(medianCount: policy.smoothingMedianCount,
                                          alpha: policy.smoothingAlpha)
        self.config = policy.acquire
    }
```

(c) Change the `config` declaration (line 44) to not hardcode `.acquire` (it is set in `init`/`reset`):

```swift
    private var config: AnalysisConfig
```

Wait — `config` is typed `AnalysisConfig` today, but bands are now `BandSpec`. Change the stored band state to `BandSpec`:

```swift
    private var config: BandSpec
```

Search the file for other `AnalysisConfig`-typed uses of `config` (e.g. `config.window`, `config.hop`, `config.label`) — `BandSpec` has the same `window`/`hop`/`label` members, so those compile unchanged.

(d) Add `setPolicy` (after `init`):

```swift
    /// Swap the detection policy (e.g. on instrument change). Resets smoother/gate
    /// and band state so the new geometry takes effect cleanly.
    public func setPolicy(_ newPolicy: DetectionPolicy) {
        policy = newPolicy
        smoother = FrequencySmoother(medianCount: newPolicy.smoothingMedianCount,
                                     alpha: newPolicy.smoothingAlpha)
        gate.reset()
        config = newPolicy.acquire
        trackedFrequency = nil
        prevFrame = nil
        phaseIntegrator.reset()
    }
```

(e) In `analyze()`, route the detector + emit gate through the policy (replace lines 112-114):

```swift
        guard let det = PitchDetector.detect(
            frame, sampleRate: sampleRate, range: policy.searchRange,
            method: method, emitFloor: policy.emitFloor
        ), det.clarity >= policy.emitFloor else {
            return handleUnvoiced()
        }
```

(f) Route the sustain gate through the current band's floor (replace line 179):

```swift
        let (emit, stable) = gate.step(confidence: det.clarity, floor: config.sustainConfidence)
```

(g) Replace `config = nextConfig(for: smoothed)` (line 234) and the whole `nextConfig` method (lines 297-318) with the testable `nextBand`:

```swift
        config = Self.nextBand(for: smoothed, current: config, in: policy)
```

```swift
    /// Pure band-transition step (testable). Reproduces the former stateful
    /// `switch`-based selection from a flat band plan: rise one band when f0 clears
    /// the band-above floor + its hysteresis; drop (to the pure-floor band) when f0
    /// falls below the current floor − its hysteresis; else stay (anti-chatter).
    static func nextBand(for f0: Double, current: BandSpec, in policy: DetectionPolicy) -> BandSpec {
        let bands = policy.bands
        guard let i = bands.firstIndex(where: { $0.label == current.label }) else {
            return policy.band(forFrequency: f0)   // acquire / unknown → settle by lookup
        }
        if i > 0 {
            let above = bands[i - 1]
            if f0 >= above.floorHz + above.hysteresisHz { return above }
        }
        if i < bands.count - 1, f0 < current.floorHz - current.hysteresisHz {
            return policy.band(forFrequency: f0)
        }
        return current
    }
```

(h) Update `reset()` (lines 93-99) to rebuild from policy:

```swift
    public func reset() {
        head = 0; filled = 0; totalSamples = 0; lastAnalyzedAt = 0
        preproc.reset(); smoother.reset(); gate.reset()
        config = policy.acquire; trackedFrequency = nil; unvoicedStreak = 0
        prevFrame = nil; phaseIntegrator.reset()
        for i in ring.indices { ring[i] = 0 }
    }
```

(i) In `handleUnvoiced()` (line 259), the long-silence reset sets `config = .acquire` — change to `config = policy.acquire`.

- [ ] **Step 4: Run tests to verify they pass**

Run: `swift test --package-path Packages/TunerEngine --filter PipelineTests`
Expected: PASS — both new tests AND all existing pipeline tests (they construct the pipeline with no `policy`, so they get `.fullRange` = legacy behavior, incl. `lowBassOctaveSafety` at E1 because `.fullRange` keeps the 27 Hz floor).

- [ ] **Step 5: Commit**

```bash
git add Packages/TunerEngine/Sources/TunerEngine/Pipeline/PitchPipeline.swift \
        Packages/TunerEngine/Tests/TunerEngineTests/PipelineTests.swift
git commit -m "feat(pipeline): route search/window/gates through DetectionPolicy (default fullRange)"
```

---

### Task 5: Guitar clamp parity test (the clamp's verifier)

**Files:**
- Test: `Packages/TunerEngine/Tests/TunerEngineTests/PipelineTests.swift`

- [ ] **Step 1: Write the test** (append to `PipelineTests`)

```swift
    @Test(arguments: [65.41, 82.41, 110.0, 196.0, 329.63])   // C2 (Drop C) … E4
    func guitarClampMatchesFullRangeOnGuitarNotes(_ f: Double) {
        func lastNote(_ policy: DetectionPolicy) throws -> (String, Double) {
            let p = PitchPipeline(sampleRate: fs, a4: 440, method: .mpm, policy: policy)
            let sig = Synth.inharmonicString(fundamental: f, sampleRate: fs, seconds: 1.0)
            let block = 480
            var rs: [PitchReading] = []
            var i = 0
            while i < sig.count { let e = min(i + block, sig.count); rs += p.process(Array(sig[i..<e])); i = e }
            let last = try #require(rs.last)
            return (last.note.description, last.cents)
        }
        let full = try lastNote(.fullRange)
        let guitar = try lastNote(.guitar)
        #expect(full.0 == guitar.0, "note identical under clamp at \(f) Hz")
        #expect(abs(full.1 - guitar.1) < 0.01, "cents identical under clamp at \(f) Hz")
    }
```

- [ ] **Step 2: Run test to verify it passes** (this asserts existing behavior, so it should pass once Task 4 lands)

Run: `swift test --package-path Packages/TunerEngine --filter guitarClampMatchesFullRange`
Expected: PASS for all 5 frequencies — confirms the 60 Hz clamp changes nothing for guitar notes (C2 = 65.4 Hz is the binding case). If C2 ever diverges, lower `.guitar.searchRange` floor or revert it to `27...1400` (spec §10).

- [ ] **Step 3: Commit**

```bash
git add Packages/TunerEngine/Tests/TunerEngineTests/PipelineTests.swift
git commit -m "test(dsp): guitar clamp (60Hz) parity vs fullRange incl. C2 Drop-C case"
```

---

### Task 6: `TunerEngine.setDetectionPolicy`

**Files:**
- Modify: `Packages/TunerEngine/Sources/TunerEngine/TunerEngine.swift` (fields `:23-34`, init `:84-94`, start `:126-128`, setters `:153-170`)
- Test: `Packages/TunerEngine/Tests/TunerEngineTests/DetectionPolicyTests.swift`

- [ ] **Step 1: Write the failing test** (append to `DetectionPolicyTests`)

```swift
    @Test func engineStoresAndUpdatesPolicy() async {
        let engine = TunerEngine(detectionPolicy: .bass)
        #expect(await engine.detectionPolicy == .bass)
        await engine.setDetectionPolicy(.guitar)
        #expect(await engine.detectionPolicy == .guitar)
    }
```

- [ ] **Step 2: Run test to verify it fails**

Run: `swift test --package-path Packages/TunerEngine --filter engineStoresAndUpdatesPolicy`
Expected: FAIL — `incorrect argument label` / `value of type 'TunerEngine' has no member 'detectionPolicy'`.

- [ ] **Step 3: Write the implementation**

In `TunerEngine.swift`, add the stored property after `targetNote` (line 34):

```swift
    /// Active per-instrument detection policy (the app sets this per instrument).
    public private(set) var detectionPolicy: DetectionPolicy
```

Add the init parameter (line 84-94) and store it:

```swift
    public init(
        a4: Double = Pitch.standardA4,
        inputPreference: InputPreference = .auto,
        method: DetectionMethod = .mpm,
        targetNote: Note? = nil,
        detectionPolicy: DetectionPolicy = .guitar
    ) {
        self.a4 = min(Pitch.maxA4, max(Pitch.minA4, a4))
        self.inputPreference = inputPreference
        self.method = method
        self.targetNote = targetNote
        self.detectionPolicy = detectionPolicy
    }
```

Pass it to the pipeline in `start()` (line 126-128):

```swift
        let pipeline = PitchPipeline(
            sampleRate: capture.sampleRate, a4: a4, method: method,
            targetNote: targetNote, policy: detectionPolicy
        )
```

Add the live setter after `setTargetNote` (line 170):

```swift
    public func setDetectionPolicy(_ value: DetectionPolicy) {
        detectionPolicy = value
        pipeline?.setPolicy(value)
    }
```

- [ ] **Step 4: Run test to verify it passes**

Run: `swift test --package-path Packages/TunerEngine --filter engineStoresAndUpdatesPolicy`
Expected: PASS.

- [ ] **Step 5: Commit**

```bash
git add Packages/TunerEngine/Sources/TunerEngine/TunerEngine.swift \
        Packages/TunerEngine/Tests/TunerEngineTests/DetectionPolicyTests.swift
git commit -m "feat(engine): setDetectionPolicy + stored detectionPolicy (default guitar)"
```

---

### Task 7: Zero-delta verification (engine)

**Files:** none (verification only)

- [ ] **Step 1: Full engine test suite**

Run: `swift test --package-path Packages/TunerEngine`
Expected: PASS — all suites green, no regressions.

- [ ] **Step 2: Accuracy benchmark, compared against the committed baseline**

Run: `swift run -c release --package-path Packages/TunerEngine Benchmark --compare --out docs/benchmarks`
Expected: the comparison reports **no change** vs `docs/benchmarks/accuracy.md` (the benchmark runs `.fullRange` = legacy). If `accuracy.md` is regenerated, `git diff docs/benchmarks/accuracy.md` must be empty (or numerically identical). If anything moved, stop — the refactor is not inert; reconcile before continuing.

- [ ] **Step 3: Commit (only if the benchmark re-emitted an identical report)**

```bash
git add -A docs/benchmarks
git commit -m "chore(bench): confirm zero-delta after DetectionPolicy refactor" --allow-empty
```

---

## Phase B — App layer (Xcode / LUMATests, macOS host)

> After creating new files under `App/`, regenerate the Xcode project: `xcodegen generate`.
> App tests run on the macOS host: `xcodebuild test -project LUMA.xcodeproj -scheme LUMA -destination 'platform=macOS'` (confirm the scheme name with `xcodebuild -list -project LUMA.xcodeproj`). Validate edits with `XcodeRefreshCodeIssuesInFile` then `BuildProject` if those MCP tools are available.

### Task 8: `InstrumentProfile` type + built-in registry

**Files:**
- Create: `App/Engine/InstrumentProfile.swift`
- Test: `LUMA/Tests/InstrumentProfileTests.swift`

- [ ] **Step 1: Write the failing test**

Create `LUMA/Tests/InstrumentProfileTests.swift`:

```swift
import Testing
import LumaDesignSystem
import TunerEngine
@testable import LUMA

@Suite struct InstrumentProfileTests {

    @Test func guitarProfileComposesGuitarPolicyAndTuning() {
        let p = InstrumentProfile.builtIn(.guitar)
        #expect(p.id == .guitar)
        #expect(p.detection == DetectionPolicy.guitar)
        #expect(p.defaultTuning.id == Tunings.guitar.id)
        #expect(p.defaultMode == .auto)
        #expect(p.defaultInput == .di)
    }

    @Test func bassProfileStaysAutoInSlice1() {
        let p = InstrumentProfile.builtIn(.bass)
        #expect(p.id == .bass)
        #expect(p.detection == DetectionPolicy.bass)
        #expect(p.defaultTuning.id == Tunings.bass.id)
        // Slice 1 defers the .lock flip (docs/todos/bass-detection-policy-tuning.md).
        #expect(p.defaultMode == .auto)
    }
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `xcodebuild test -project LUMA.xcodeproj -scheme LUMA -destination 'platform=macOS' -only-testing:LUMATests/InstrumentProfileTests`
Expected: FAIL — `cannot find 'InstrumentProfile' in scope`.

- [ ] **Step 3: Write the implementation**

Create `App/Engine/InstrumentProfile.swift`:

```swift
import LumaDesignSystem
import TunerEngine

/// The unifying, first-class instrument profile (DESIGN: instrument-profiles §4-5).
/// Lives in the App layer — the only place allowed to compose a `Tuning`
/// (LumaDesignSystem) with a `DetectionPolicy` (TunerEngine) plus UX defaults,
/// since neither package may import the other. Built-in profiles are
/// code-defined (not persisted); custom *tunings* remain `TuningCard`'s job.
struct InstrumentProfile: Identifiable, Sendable {
    let id: Instrument
    var displayName: String
    var defaultTuning: Tuning
    var detection: DetectionPolicy
    var defaultMode: TargetMode
    var defaultInput: InputKind

    /// The code-defined built-in profile for an instrument.
    static func builtIn(_ instrument: Instrument) -> InstrumentProfile {
        switch instrument {
        case .guitar:
            return InstrumentProfile(
                id: .guitar, displayName: "Guitar",
                defaultTuning: Tunings.guitar, detection: .guitar,
                defaultMode: .auto, defaultInput: .di
            )
        case .bass:
            return InstrumentProfile(
                id: .bass, displayName: "Bass",
                defaultTuning: Tunings.bass, detection: .bass,
                // Slice 1: bass stays .auto. The deferred bass-fix flips this to .lock.
                defaultMode: .auto, defaultInput: .di
            )
        }
    }
}
```

- [ ] **Step 4: Run test to verify it passes**

Run: `xcodebuild test -project LUMA.xcodeproj -scheme LUMA -destination 'platform=macOS' -only-testing:LUMATests/InstrumentProfileTests`
Expected: PASS (2 tests).

- [ ] **Step 5: Commit**

```bash
git add App/Engine/InstrumentProfile.swift LUMA/Tests/InstrumentProfileTests.swift project.yml
git commit -m "feat(app): add first-class InstrumentProfile + built-in registry"
```

---

### Task 9: Migrate `LiveTunerModel` to drive the policy; policy-driven lock floor

**Files:**
- Modify: `App/Engine/PitchReadingStrobe.swift` (whole file)
- Modify: `App/Engine/LiveTunerModel.swift` (fields `:37-42`, `start` `:89-93`, `setInstrument` `:155-159`, `apply` `:229-251`)
- Test: `LUMA/Tests/LiveTunerModelProfileTests.swift`

- [ ] **Step 1: Write the failing test**

Create `LUMA/Tests/LiveTunerModelProfileTests.swift`:

```swift
import Testing
import LumaDesignSystem
import TunerEngine
@testable import LUMA

@MainActor
@Suite struct LiveTunerModelProfileTests {

    @Test func setInstrumentSwapsProfileAndTuning() {
        let model = LiveTunerModel()
        #expect(model.profile.id == .guitar)          // launch default
        model.setInstrument(.bass)
        #expect(model.profile.id == .bass)
        #expect(model.tuning.id == Tunings.bass.id)
    }

    @Test func lockFloorComesFromActiveProfile() {
        let model = LiveTunerModel()
        model.setInstrument(.guitar)
        // Guitar low band (< 120 Hz) → 0.75, mid/high → 0.90 (former minLockConfidence).
        #expect(model.profile.detection.lockConfidence(forFrequency: 82) == 0.75)
        #expect(model.profile.detection.lockConfidence(forFrequency: 330) == 0.90)
    }
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `xcodebuild test -project LUMA.xcodeproj -scheme LUMA -destination 'platform=macOS' -only-testing:LUMATests/LiveTunerModelProfileTests`
Expected: FAIL — `value of type 'LiveTunerModel' has no member 'profile'`.

- [ ] **Step 3a: Update `PitchReadingStrobe.swift`** (replace the whole file)

```swift
import LumaDesignSystem
import TunerEngine

/// The seam between the engine and the design system, kept in the **app layer** so
/// `TunerEngine` stays UI-free and `LumaDesignSystem` stays logic-free (DESIGN §5).
///
/// `phase` passes straight through. The lock-confidence floor is now supplied by
/// the active `InstrumentProfile`'s `DetectionPolicy` (caller passes it in) rather
/// than a hardcoded frequency split — single source of truth (docs/todos M3).
extension PitchReading {
    /// Map a reading to the strobe's render contract, gating `locked` on the
    /// profile-supplied confidence floor.
    func strobeInput(lockCents: Double = LumaMusic.lockCents,
                     minLockConfidence: Double) -> StrobeInput {
        StrobeInput(
            cents: Float(cents),
            phase: Float(phase),
            locked: isLocked(lockCents: lockCents, minConfidence: minLockConfidence),
            isIdle: false
        )
    }
}
```

- [ ] **Step 3b: Update `LiveTunerModel.swift`**

Replace the targeting fields (lines 37-42) — add `profile`, keep `tuning`/`mode`/`activeIdx`/`targetNote`; `instrument` becomes computed:

```swift
    // MARK: Targeting / tuning
    private(set) var profile: InstrumentProfile = .builtIn(.guitar)
    var instrument: Instrument { profile.id }
    private(set) var tuning: Tuning = Tunings.standard(for: .guitar)
    private(set) var mode: TargetMode = .auto
    /// The selected string's `idx` (string-lock target / tone source); `nil` = none.
    private(set) var activeIdx: Int?
    @ObservationIgnored private(set) var targetNote: Note?
```

In `start()` (after `await engine.setA4(a4)`, line 90), push the policy:

```swift
            await engine.setA4(a4)
            await engine.setDetectionPolicy(profile.detection)
            await engine.setInputPreference(inputKind == .mic ? .mic : .auto)
            await engine.setTargetNote(targetNote)
```

Replace `setInstrument(_:)` (lines 155-159):

```swift
    func setInstrument(_ newValue: Instrument) {
        guard newValue != profile.id else { return }
        profile = .builtIn(newValue)
        mode = profile.defaultMode
        inputKind = profile.defaultInput
        let e = engine
        let pol = profile.detection
        Task { await e.setDetectionPolicy(pol) }
        setTuning(profile.defaultTuning)   // keeps activeIdx valid, updates target + tone
    }
```

In `apply(_:)`, replace the lock-floor usages. In the `.lock` branch (line 234):

```swift
            let floor = profile.detection.lockConfidence(forFrequency: adjFreq)
            let c = target.cents(of: adjFreq, a4: a4)
            let locked = abs(c) <= LumaMusic.lockCents && r.confidence >= floor
```

In the `.auto` branch (replace lines 249-250 where `r.strobeInput()` is called):

```swift
            let floor = profile.detection.lockConfidence(forFrequency: adjFreq)
            let si = r.strobeInput(minLockConfidence: floor)
            strobeInput = si
```

- [ ] **Step 4: Run test to verify it passes**

Run: `xcodebuild test -project LUMA.xcodeproj -scheme LUMA -destination 'platform=macOS' -only-testing:LUMATests/LiveTunerModelProfileTests`
Expected: PASS (2 tests). Also confirm the app still builds: `xcodebuild build -project LUMA.xcodeproj -scheme LUMA -destination 'platform=macOS'`.

- [ ] **Step 5: Commit**

```bash
git add App/Engine/PitchReadingStrobe.swift App/Engine/LiveTunerModel.swift \
        LUMA/Tests/LiveTunerModelProfileTests.swift
git commit -m "feat(app): LiveTunerModel drives DetectionPolicy; profile-driven lock floor"
```

---

### Task 10: Persist & restore last-used instrument and tuning

**Files:**
- Modify: `App/Engine/LiveTunerModel.swift` (storage props near `:46-51`, `init` `:76-79`, `setInstrument`/`setTuning` `:155-169`)
- Test: `LUMA/Tests/LiveTunerModelProfileTests.swift`

- [ ] **Step 1: Write the failing test** (append to `LiveTunerModelProfileTests`)

```swift
    @Test func restoresPersistedInstrumentAndTuning() {
        // Simulate a prior session having stored bass + Drop D.
        let d = UserDefaults.standard
        d.set(Instrument.bass.rawValue, forKey: "lastInstrument")
        d.set("bass-drop-d", forKey: "lastTuningId")
        defer { d.removeObject(forKey: "lastInstrument"); d.removeObject(forKey: "lastTuningId") }

        let model = LiveTunerModel()
        model.restoreLastSession()
        #expect(model.profile.id == .bass)
        #expect(model.tuning.id == "bass-drop-d")
    }
```

- [ ] **Step 2: Run test to verify it fails**

Run: `xcodebuild test -project LUMA.xcodeproj -scheme LUMA -destination 'platform=macOS' -only-testing:LUMATests/LiveTunerModelProfileTests/restoresPersistedInstrumentAndTuning`
Expected: FAIL — `value of type 'LiveTunerModel' has no member 'restoreLastSession'`.

- [ ] **Step 3: Write the implementation**

In `LiveTunerModel.swift`, add storage properties near the other `@AppStorage` (after line 51):

```swift
    @ObservationIgnored @AppStorage("lastInstrument") private var lastInstrument = Instrument.guitar.rawValue
    @ObservationIgnored @AppStorage("lastTuningId") private var lastTuningId = Tunings.guitar.id
```

Persist on change — append to `setInstrument(_:)` (end of the method) and `setTuning(_:)`:

```swift
        lastInstrument = newValue.rawValue   // in setInstrument, after profile/tuning set
```

```swift
        lastTuningId = newTuning.id          // in setTuning, after tuning is assigned
```

Add the restore method (after `init`), mapping the stored ids back to a profile/tuning:

```swift
    /// Restore the last-used instrument + tuning (call once at launch). First launch
    /// keeps the guitar defaults. Unknown ids fall back to the instrument's standard.
    func restoreLastSession() {
        let instrument = Instrument(rawValue: lastInstrument) ?? .guitar
        setInstrument(instrument)
        if let saved = Tunings.presets(for: instrument).first(where: { $0.id == lastTuningId }) {
            setTuning(saved)
        }
    }
```

Note: `setInstrument` early-returns if the instrument is unchanged (guitar→guitar on first launch), so call `setTuning` after it regardless — the code above does. Wire `restoreLastSession()` into the app's root view `.task`/`.onAppear` (e.g. `LiveTunerScreen`); add that call where the model is created.

- [ ] **Step 4: Run test to verify it passes**

Run: `xcodebuild test -project LUMA.xcodeproj -scheme LUMA -destination 'platform=macOS' -only-testing:LUMATests/LiveTunerModelProfileTests`
Expected: PASS (3 tests).

- [ ] **Step 5: Commit**

```bash
git add App/Engine/LiveTunerModel.swift LUMA/Tests/LiveTunerModelProfileTests.swift
git commit -m "feat(app): persist & restore last-used instrument and tuning"
```

---

### Task 11: Full app build + verification

**Files:** none (verification only)

- [ ] **Step 1: Regenerate the project and build for both platforms**

Run: `xcodegen generate`
Run: `xcodebuild build -project LUMA.xcodeproj -scheme LUMA -destination 'platform=macOS'`
Run: `xcodebuild build -project LUMA.xcodeproj -scheme LUMA -destination 'generic/platform=iOS Simulator'`
Expected: both succeed (multiplatform parity).

- [ ] **Step 2: Run the full app test suite**

Run: `xcodebuild test -project LUMA.xcodeproj -scheme LUMA -destination 'platform=macOS' -only-testing:LUMATests`
Expected: PASS — including the existing `LUMATests` lock-cents coupling guard (`PitchReading.lockCents == LumaMusic.lockCents`), which is untouched.

- [ ] **Step 3: Re-run the engine suite + benchmark once more (full-stack zero-delta)**

Run: `swift test --package-path Packages/TunerEngine`
Run: `swift run -c release --package-path Packages/TunerEngine Benchmark --compare --out docs/benchmarks`
Expected: green; benchmark unchanged.

- [ ] **Step 4: Commit any project regen**

```bash
git add project.yml LUMA.xcodeproj
git commit -m "chore(xcode): regenerate project for InstrumentProfile sources" --allow-empty
```

---

## Self-Review

**Spec coverage:**
- §4 3-layer split → Tasks 1 (engine), 8 (app `InstrumentProfile`). ✓
- §5 `DetectionPolicy`/`BandSpec`, per-band floors, `emitFloor` scalar, band table → Tasks 1, 2, 3. ✓
- §5 band-transition semantics + guitar table → Task 4 (`nextBand`) + Task 4 sweep test. ✓
- §6 engine threading (`setDetectionPolicy`, pipeline reads policy, `.fullRange` default, lock-floor lookup) → Tasks 4, 6, 9. ✓
- §7 `LiveTunerModel` migration → Task 9. ✓
- §8 `TuningCard` no schema change → unchanged; `setInstrument` pulls policy (Task 9) so `loadCard` works as-is. ✓
- §9 persistence → Task 10. ✓
- §10 guitar clamp + parity verification incl. C2 → Task 1 (value) + Task 5 (parity test). ✓
- §11 Slice-1 inert; bass stays `.auto` → Task 8 asserts `.auto`; Task 7 benchmark zero-delta. ✓
- §12 testing (bidirectional sweep, clamp parity incl. C2, lock-floor lookup, custom-plan plumbing, `setPolicy` no-crash) → Tasks 4, 5, 1, 9. ✓

**Placeholder scan:** none — every step has concrete code/commands.

**Type consistency:** `DetectionPolicy`, `BandSpec`, `PitchPipeline.nextBand`, `setPolicy`, `setDetectionPolicy`, `detectionPolicy`, `InstrumentProfile.builtIn(_:)`, `strobeInput(lockCents:minLockConfidence:)`, `restoreLastSession()`, and `lockConfidence(forFrequency:)`/`sustainConfidence(forFrequency:)` are used consistently across tasks. `config` retyped `AnalysisConfig → BandSpec` in Task 4 (members `window`/`hop`/`label` preserved).

**Known acceptable divergence:** `nextBand`'s "drop" uses pure-floor lookup for all bands, whereas legacy `nextConfig` dropped mid/low to the fixed adjacent band. These differ only on an implausible multi-band single-hop drop (blocked by the octave guard + 120¢ snap), never on the fine/monotonic trajectories the sweep test and real signals produce — so the benchmark (running `.fullRange`) stays byte-identical. Documented in Task 4.
