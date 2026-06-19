# Bass DetectionPolicy Tuning Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Make bass *settle* on a sustained note (kill DSP-lock shatter, strobe flicker, and note-name flips on E1/A1/B0) by tuning the inert `.bass` `DetectionPolicy`, measured against bass-specific lock stability and regression-guarded by a CI gate — with guitar behavior byte-identical.

**Architecture:** The benchmark is policy-agnostic today (every case runs under `.fullRange`), so Phase 0 first makes the harness policy-aware and adds a lock-retention/drop ruler, then runs the existing sustained bass cases under `.bass` to baseline. Phase 1 tunes the *bass-isolated* policy values (band geometry, acquire window, confidence floors). A measured decision gate then decides whether the *shared-code* Phase 2 changes (octave-rescue floor decoupling, phase-integrator grace period) are needed. Phase 3 flips bass to `.lock` and fixes the `setInstrument` side-effect gap. Phase 4 locks in the CI gate with an empirically-grounded threshold and re-baselines.

**Tech Stack:** Swift 5.9+, Swift Testing (`@Test`/`#expect`), `swift test --package-path Packages/TunerEngine` for engine tests, Xcode `LUMATests` target for App tests, the `Benchmark` executable (`swift run -c release --package-path Packages/TunerEngine Benchmark`).

## Global Constraints

- **Guitar zero-delta.** The guitar/`fullRange` `PitchReading` stream and all existing guitar accuracy/σ numbers must not change. Any shared-code edit must be guarded by the `guitarClampMatchesFullRangeOnGuitarNotes` pattern (`PipelineTests.swift:193-209`). Adding bass report columns/sections is allowed; guitar *values* must not move.
- **Octave-error stays 0.00%.** CI hard invariants: `octaveErrorRate > 0` and `stressOctaveErrors > 0` both fail the build (`Benchmark/main.swift`). Never regress these.
- **`maxWindow` stays 8192.** `AnalysisConfig.maxWindow = 8192` sizes the shared pipeline ring buffer (`PitchPipeline.cap`). The bass long window is therefore capped at 8192 — do not raise `maxWindow` (it is shared with guitar).
- **Bass-isolated vs shared.** `DetectionPolicy.bass` values may change freely (cannot affect guitar). `PitchDetector.hybrid`, `PitchPipeline.process`, and `AnalysisConfig` are shared — touch only behind the guitar guard, and only in Phase 2 if the decision gate requires it.
- **No new networking; `TunerEngine` stays UI-free; no SwiftUI import in the package. No force-unwrapping in production paths. Swift Concurrency only (no Combine).**
- **Never red-light CI on landing.** The benchmark is CI-blocking. The Phase 4 bass gate threshold must be set from the *tuned* measured number plus margin, never guessed.
- **Branch:** work is on `feat/bass-detection-policy-tuning` (already created). Commit after every task.

---

## Phase 0 — Make the harness policy-aware + build the ruler

### Task 1: Thread a `policy:` parameter through `CaseRunner.run`

The benchmark's only `PitchPipeline(` construction site is `Metrics.swift:71` and it passes no policy, so every case runs `.fullRange`. Add an opt-in `policy:` parameter that defaults to `.fullRange` (preserving guitar zero-delta) so callers can drive cases under `.bass`.

**Files:**
- Modify: `Packages/TunerEngine/Sources/TunerEngine/Bench/Metrics.swift` (`CaseRunner.run`, the `PitchPipeline(...)` call at line 71)
- Test: `Packages/TunerEngine/Tests/TunerEngineTests/BenchmarkTests.swift`

**Interfaces:**
- Produces: `CaseRunner.run(signal:sampleRate:trueFrequency:category:centsTarget:snrDB:method:a4:lockTolerance:steadyStateStart:lockWindowStart:policy:)` where `policy: DetectionPolicy = .fullRange` is the new trailing parameter; the pipeline is built as `PitchPipeline(sampleRate: sampleRate, a4: a4, method: method, policy: policy)`.

- [ ] **Step 1: Write the failing test**

Add to `BenchmarkTests.swift`:

```swift
@Test func caseRunnerPolicyParamRoutesToPipeline() {
    let fs = 48_000.0
    let sig = Synth.inharmonicString(fundamental: 110, sampleRate: fs, seconds: 1.2)

    // Default policy == .fullRange (backward-compatible, zero-delta).
    let dflt = CaseRunner.run(signal: sig, sampleRate: fs, trueFrequency: 110,
                              category: "t", centsTarget: 0, snrDB: .infinity, method: .mpm)
    let full = CaseRunner.run(signal: sig, sampleRate: fs, trueFrequency: 110,
                              category: "t", centsTarget: 0, snrDB: .infinity, method: .mpm,
                              policy: .fullRange)
    #expect(dflt.readings == full.readings)
    #expect(dflt.stats == full.stats)

    // A policy whose searchRange excludes 110 Hz must change the result —
    // proves the parameter actually reaches the pipeline.
    let narrow = DetectionPolicy(searchRange: 200...400, bands: DetectionPolicy.fullRange.bands,
                                 acquire: DetectionPolicy.fullRange.acquire,
                                 smoothingAlpha: 0.35, smoothingMedianCount: 5, emitFloor: 0.5)
    let clamped = CaseRunner.run(signal: sig, sampleRate: fs, trueFrequency: 110,
                                 category: "t", centsTarget: 0, snrDB: .infinity, method: .mpm,
                                 policy: narrow)
    #expect(clamped.stats.meanAbs != full.stats.meanAbs, "narrow searchRange must change the estimate")
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `swift test --package-path Packages/TunerEngine --filter caseRunnerPolicyParamRoutesToPipeline`
Expected: FAIL — `extra argument 'policy' in call` (the parameter does not exist yet).

- [ ] **Step 3: Add the parameter and thread it**

In `Metrics.swift`, add the parameter to the `run` signature (after `lockWindowStart`):

```swift
        lockWindowStart: TimeInterval = 1.0,
        policy: DetectionPolicy = .fullRange
    ) -> CaseResult {
        let pipeline = PitchPipeline(sampleRate: sampleRate, a4: a4, method: method, policy: policy)
```

- [ ] **Step 4: Run test to verify it passes**

Run: `swift test --package-path Packages/TunerEngine --filter caseRunnerPolicyParamRoutesToPipeline`
Expected: PASS.

- [ ] **Step 5: Run the full engine suite to confirm zero-delta**

Run: `swift test --package-path Packages/TunerEngine`
Expected: PASS (all existing tests still green — the default `.fullRange` keeps every existing caller byte-identical).

- [ ] **Step 6: Commit**

```bash
git add Packages/TunerEngine/Sources/TunerEngine/Bench/Metrics.swift Packages/TunerEngine/Tests/TunerEngineTests/BenchmarkTests.swift
git commit -m "feat(bench): thread policy: param through CaseRunner.run (default .fullRange)

Co-Authored-By: Claude Opus 4.8 (1M context) <noreply@anthropic.com>"
```

---

### Task 2: Add lock-retention % and lock-drop count to the ruler

`timeToLock` is first-lock-only and never notices a mid-sustain lock loss. Add a pure trajectory function over the held-note window and surface it on `CaseResult`. "Locked" is defined on the DSP-observable `isLockIntegrated` flag (the phase-integrator lock), which is exactly RC2's shatter signal.

**Files:**
- Modify: `Packages/TunerEngine/Sources/TunerEngine/Bench/Metrics.swift` (`CaseResult`, `CaseRunner.run`, new `CaseRunner.lockTrajectory`)
- Test: `Packages/TunerEngine/Tests/TunerEngineTests/BenchmarkTests.swift`

**Interfaces:**
- Consumes: Task 1's `policy:` parameter is unrelated here; this task only reads `PitchReading.isLockIntegrated` and `.timestamp`.
- Produces: `CaseResult.lockRetention: Double` (0…1, fraction of held-window frames with `isLockIntegrated`), `CaseResult.lockDrops: Int` (lock→unlock transitions in the window); `static func CaseRunner.lockTrajectory(_ readings: [PitchReading], windowStart: TimeInterval) -> (retention: Double, drops: Int)`.

- [ ] **Step 1: Write the failing test**

Add to `BenchmarkTests.swift`:

```swift
@Test func lockTrajectoryComputesRetentionAndDrops() {
    func r(_ t: TimeInterval, _ locked: Bool) -> PitchReading {
        PitchReading(frequency: 110, note: Note(midi: 45), cents: 0, confidence: 0.9,
                     phase: 0, timestamp: t, inharmonicityB: nil,
                     precisionCents: locked ? 0.1 : nil, isLockIntegrated: locked)
    }
    // Pre-window frames (t < 1.0) are ignored. In-window: L, L, unlocked, L → one drop,
    // 3/4 locked.
    let readings = [r(0.5, true), r(1.0, true), r(1.2, true), r(1.4, false), r(1.6, true)]
    let (retention, drops) = CaseRunner.lockTrajectory(readings, windowStart: 1.0)
    #expect(abs(retention - 0.75) < 1e-9)
    #expect(drops == 1)

    // Never locks in window → 0 retention, 0 drops.
    let none = [r(1.0, false), r(1.2, false)]
    let (ret2, drops2) = CaseRunner.lockTrajectory(none, windowStart: 1.0)
    #expect(ret2 == 0)
    #expect(drops2 == 0)
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `swift test --package-path Packages/TunerEngine --filter lockTrajectoryComputesRetentionAndDrops`
Expected: FAIL — `type 'CaseRunner' has no member 'lockTrajectory'`.

- [ ] **Step 3: Implement `lockTrajectory` and wire it into `CaseResult`**

In `Metrics.swift`, add the two fields to `CaseResult` (after `lockErrors`):

```swift
    public let lockErrors: [Double]  // lock-window cents errors (for pooling)
    public let lockRetention: Double // 0…1: held-window frames with isLockIntegrated (RC2/RC3)
    public let lockDrops: Int        // lock→unlock transitions in the held window
```

Add the pure function to `CaseRunner` (above `run`):

```swift
    /// Held-note lock trajectory: fraction of in-window frames that hold the
    /// phase-integrator lock, and the count of lock→unlock transitions (the
    /// "won't settle" symptom σ alone misses). Window = readings at/after windowStart.
    static func lockTrajectory(_ readings: [PitchReading], windowStart: TimeInterval)
        -> (retention: Double, drops: Int) {
        let flags = readings.filter { $0.timestamp >= windowStart }.map { $0.isLockIntegrated }
        guard !flags.isEmpty else { return (0, 0) }
        let retention = Double(flags.filter { $0 }.count) / Double(flags.count)
        var drops = 0
        if flags.count > 1 {
            for i in 1..<flags.count where flags[i - 1] && !flags[i] { drops += 1 }
        }
        return (retention, drops)
    }
```

In `run`, compute it just after `lockStats` and pass it into the `CaseResult(...)`:

```swift
        let lockStats = ErrorStats.from(lockErrors)
        let (lockRetention, lockDrops) = lockTrajectory(readings, windowStart: lockWindowStart)

        return CaseResult(
            category: category, note: noteLabel(trueFrequency, a4: a4),
            trueFrequency: trueFrequency, centsTarget: centsTarget, snrDB: snrDB,
            readings: steady.count, stats: stats,
            octaveError: octaveError, timeToLockMS: timeToLock, errors: errors,
            lockStats: lockStats, lockErrors: lockErrors,
            lockRetention: lockRetention, lockDrops: lockDrops
        )
```

- [ ] **Step 4: Run test to verify it passes**

Run: `swift test --package-path Packages/TunerEngine --filter lockTrajectoryComputesRetentionAndDrops`
Expected: PASS.

- [ ] **Step 5: Run the full engine suite**

Run: `swift test --package-path Packages/TunerEngine`
Expected: PASS (the new `CaseResult` fields have call sites updated; no behavior change).

- [ ] **Step 6: Commit**

```bash
git add Packages/TunerEngine/Sources/TunerEngine/Bench/Metrics.swift Packages/TunerEngine/Tests/TunerEngineTests/BenchmarkTests.swift
git commit -m "feat(bench): add lock-retention/drop trajectory to CaseResult

Co-Authored-By: Claude Opus 4.8 (1M context) <noreply@anthropic.com>"
```

---

### Task 3: Add a `.bass`-policy pass + bass-specific reporting to the suite

Run the bass notes and the weak-fund family under `policy: .bass` in a *separate* pass so the existing clean/noise/stress sections stay byte-identical (guitar zero-delta). Expose bass σ / retention / drops on `Summary` and a markdown section. No gate yet (added in Phase 4 once tuned).

**Files:**
- Modify: `Packages/TunerEngine/Sources/TunerEngine/Bench/BenchmarkSuite.swift` (`Summary`, `run`, `summarize`, `markdown`)
- Test: `Packages/TunerEngine/Tests/TunerEngineTests/BenchmarkTests.swift`

**Interfaces:**
- Consumes: `CaseRunner.run(..., policy:)` (Task 1), `CaseResult.lockRetention`/`.lockDrops` (Task 2).
- Produces: `Summary.bassLockSigma: Double`, `Summary.bassLockRetention: Double`, `Summary.bassLockDrops: Int`, `Summary.bassPolicyCases: Int`. A new private `bassPolicyNotes: [Int]` and the `bassPolicy: [CaseResult]` pass inside `run`.

- [ ] **Step 1: Write the failing test**

Add to `BenchmarkTests.swift`:

```swift
@Test func benchmarkExposesBassPolicySummary() {
    let report = BenchmarkSuite.run(method: .mpm, dateLabel: "test")
    #expect(report.summary.bassPolicyCases > 0, "bass-policy pass must run cases")
    #expect(report.summary.bassLockRetention >= 0 && report.summary.bassLockRetention <= 1)
    #expect(report.markdown.contains("Bass policy"), "markdown has a bass-policy section")
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `swift test --package-path Packages/TunerEngine --filter benchmarkExposesBassPolicySummary`
Expected: FAIL — `value of type 'Summary' has no member 'bassPolicyCases'`.

- [ ] **Step 3: Add `Summary` fields**

In `BenchmarkSuite.swift`, append to `struct Summary`:

```swift
        public let cases: Int
        public let bassLockSigma: Double       // held-note lock σ, bass notes under .bass
        public let bassLockRetention: Double    // mean held-window lock retention, bass under .bass
        public let bassLockDrops: Int           // total lock drops, bass under .bass
        public let bassPolicyCases: Int
```

- [ ] **Step 4: Add the bass-policy pass and aggregation**

Add the note set near the other matrices (after `noiseNotes`):

```swift
    // Bass-policy pass: bass strings run under .bass (not the default .fullRange),
    // scored separately so the guitar clean matrix stays byte-identical.
    private static let bassPolicyNotes = [23, 28, 33, 38, 43]   // B0 E1 A1 D2 G2
```

In `run`, after the stress loops and before `summarize`, add the pass:

```swift
        // Bass-policy pass (under .bass): clean inharmonic + weak-fund, the settle stressors.
        var bassPolicy: [CaseResult] = []
        for midi in bassPolicyNotes {
            let base = Pitch.frequency(midi: midi, a4: a4)
            let seconds = coreSeconds(base)
            let clean = Synth.inharmonicString(fundamental: base, sampleRate: sampleRate, seconds: seconds)
            bassPolicy.append(CaseRunner.run(signal: clean, sampleRate: sampleRate, trueFrequency: base,
                                             category: "bass-clean", centsTarget: 0, snrDB: .infinity,
                                             method: method, a4: a4, lockWindowStart: lockWindowStart,
                                             policy: .bass))
            let weak = Synth.inharmonicString(fundamental: base, sampleRate: sampleRate, seconds: seconds,
                                              fundamentalLevel: 0.15)
            bassPolicy.append(CaseRunner.run(signal: weak, sampleRate: sampleRate, trueFrequency: base,
                                             category: "bass-weak-fund", centsTarget: 0, snrDB: .infinity,
                                             method: method, a4: a4, lockWindowStart: lockWindowStart,
                                             policy: .bass))
        }
```

Update the `summarize` call and the return so the report carries the pass:

```swift
        let summary = summarize(clean: clean, stress: stress, bassPolicy: bassPolicy, method: method)
        let all = clean + noise
        return Report(
            csv: csv(all + stress + bassPolicy),
            markdown: markdown(clean: clean, noise: noise, stress: stress, bassPolicy: bassPolicy,
                               summary: summary, sampleRate: sampleRate, a4: a4, dateLabel: dateLabel),
            summary: summary
        )
```

Update `summarize` to accept and aggregate the pass:

```swift
    private static func summarize(clean: [CaseResult], stress: [CaseResult],
                                  bassPolicy: [CaseResult], method: DetectionMethod) -> Summary {
```

and before the `return Summary(`:

```swift
        let bassLock = ErrorStats.from(bassPolicy.flatMap { $0.lockErrors })
        let bassRetention = bassPolicy.isEmpty ? 0
            : bassPolicy.map { $0.lockRetention }.reduce(0, +) / Double(bassPolicy.count)
        let bassDrops = bassPolicy.reduce(0) { $0 + $1.lockDrops }
```

add the four fields to the `Summary(...)` initializer call:

```swift
            cases: clean.count + stress.count,
            bassLockSigma: bassLock.sigma,
            bassLockRetention: bassRetention,
            bassLockDrops: bassDrops,
            bassPolicyCases: bassPolicy.count
```

- [ ] **Step 5: Add the markdown section and update the `markdown`/`csv` signatures**

Change `markdown`'s signature to accept `bassPolicy: [CaseResult]`:

```swift
    private static func markdown(
        clean: [CaseResult], noise: [CaseResult], stress: [CaseResult], bassPolicy: [CaseResult],
        summary: Summary, sampleRate: Double, a4: Double, dateLabel: String
    ) -> String {
```

Insert this section just before `md += crlbSection(...)`:

```swift
        md += "\n## Bass policy (bass notes under `.bass`)\n\n"
        md += "Bass strings driven through the **`.bass`** DetectionPolicy (the rest of the report uses "
        md += "`.fullRange`). Lock retention = fraction of held-window frames holding the phase-integrator "
        md += "lock; drops = mid-sustain lock losses. This is the bass-settling signal the Phase 4 gate reads.\n\n"
        md += "| Family | n | abs ¢ | lock σ ¢ | lock retention | lock drops |\n|---|---|---|---|---|---|\n"
        for fam in ["bass-clean", "bass-weak-fund"] {
            let inF = bassPolicy.filter { $0.category == fam }
            guard !inF.isEmpty else { continue }
            let p = ErrorStats.from(inF.flatMap { $0.errors })
            let lp = ErrorStats.from(inF.flatMap { $0.lockErrors })
            let ret = inF.map { $0.lockRetention }.reduce(0, +) / Double(inF.count)
            let drops = inF.reduce(0) { $0 + $1.lockDrops }
            md += "| \(fam) | \(p.count) | \(f2(p.meanAbs)) | \(f2(lp.sigma)) | \(f2(ret * 100))% | \(drops) |\n"
        }
```

The `csv` already takes `[CaseResult]`; the bass-policy rows flow in via the `csv(all + stress + bassPolicy)` change in Step 4. (Optionally add `lock_retention,lock_drops` columns to the CSV header/rows — not required for the gate; skip to keep the diff small unless you want them.)

- [ ] **Step 6: Run the test + full suite**

Run: `swift test --package-path Packages/TunerEngine --filter benchmarkExposesBassPolicySummary`
Expected: PASS.
Run: `swift test --package-path Packages/TunerEngine`
Expected: PASS.

- [ ] **Step 7: Commit**

```bash
git add Packages/TunerEngine/Sources/TunerEngine/Bench/BenchmarkSuite.swift Packages/TunerEngine/Tests/TunerEngineTests/BenchmarkTests.swift
git commit -m "feat(bench): add .bass-policy pass + bass lock σ/retention/drops reporting

Co-Authored-By: Claude Opus 4.8 (1M context) <noreply@anthropic.com>"
```

---

### Task 4: Baseline the inert `.bass` policy

Capture the "before" numbers (the bass-policy pass currently runs `.bass`, which is still guitar values except searchRange). This is the documented baseline the rest of the work improves on, and it sets the thresholds for the Phase 1 tests and the Phase 4 gate.

**Files:**
- Create: `docs/benchmarks/bass-baseline.md` (the recorded baseline)

**Interfaces:**
- Consumes: the `.bass`-policy summary from Task 3.

- [ ] **Step 1: Run the benchmark and capture the bass-policy section**

Run: `swift run -c release --package-path Packages/TunerEngine Benchmark --method mpm 2>/dev/null`
Read the **"Bass policy"** markdown section from stdout (and the `bass-clean` / `bass-weak-fund` rows).

- [ ] **Step 2: Record the baseline**

Create `docs/benchmarks/bass-baseline.md` with: the date, the command, and a verbatim copy of the "Bass policy" table plus `summary.bassLockSigma`, `bassLockRetention`, `bassLockDrops`. Add one sentence noting whether synthetic stimulus already settles (high retention) or exhibits the shatter (low retention / drops > 0) — this determines how much Phase 1 can demonstrate on synthetic tones vs. what is defensive for real DI.

- [ ] **Step 3: Commit**

```bash
git add docs/benchmarks/bass-baseline.md
git commit -m "docs(bench): record inert .bass baseline (lock σ/retention/drops)

Co-Authored-By: Claude Opus 4.8 (1M context) <noreply@anthropic.com>"
```

---

## Phase 1 — Tune bass-isolated levers

> Each task here is a measure→change→measure loop with a concrete failing test, a concrete first-hypothesis edit, and fixed acceptance thresholds. If the baseline (Task 4) already meets a threshold for synthetic stimulus, record that the lever is defensive (for weak real-DI) and keep the change minimal/justified rather than forcing a no-op.

### Task 5: Tune `bass.bands` + `bass.acquire` geometry (E1/A1 need the long window)

E1 (41.2 Hz) and A1 (55 Hz) fall in the `low` band's 4096 window — sized for guitar's 82 Hz low E (~7 periods); E1 gets only ~3.5. Extend the bass long window upward so the bottom strings get adequate periods. Capped at 8192 (`maxWindow`, shared).

**Files:**
- Modify: `Packages/TunerEngine/Sources/TunerEngine/DSP/DetectionPolicy.swift` (`static let bass`)
- Test: `Packages/TunerEngine/Tests/TunerEngineTests/PipelineTests.swift`, `Packages/TunerEngine/Tests/TunerEngineTests/DetectionPolicyTests.swift`

**Interfaces:**
- Consumes: `CaseRunner`/bench reporting (Tasks 1–3) for measurement; `PitchPipeline(policy:)`.
- Produces: a tuned `DetectionPolicy.bass.bands`/`.acquire` (bass-isolated; does not touch `.fullRange`/`.guitar`).

- [ ] **Step 1: Write the failing bass-settle test**

Add to `PipelineTests.swift` (reuses the file's `run`-style block driving + `sigma` helper):

```swift
@Test func weakFundE1SettlesUnderBassPolicy() {
    let f = 41.20   // E1, the canonical bass settle stressor
    let sig = Synth.inharmonicString(fundamental: f, sampleRate: fs, seconds: 2.6, fundamentalLevel: 0.15)
    let p = PitchPipeline(sampleRate: fs, a4: 440, method: .mpm, policy: .bass)
    let block = 480
    var rs: [PitchReading] = []
    var i = 0
    while i < sig.count { let e = min(i + block, sig.count); rs += p.process(Array(sig[i..<e])); i = e }

    let window = rs.filter { $0.timestamp >= 1.0 }
    #expect(window.count > 5, "must produce a held-note window")
    let retention = Double(window.filter { $0.isLockIntegrated }.count) / Double(window.count)
    #expect(retention >= 0.85, "E1 weak-fund should hold DSP lock through the sustain")
    #expect(sigma(window.map(\.cents)) < 0.30, "held-note jitter must be strobe-grade")
    // Octave-safety must never regress while tuning.
    #expect(window.allSatisfy { abs(TestSupport.cents($0.frequency, f)) < 600 }, "no octave slip on E1")
}
```

- [ ] **Step 2: Run test to verify it fails (baseline)**

Run: `swift test --package-path Packages/TunerEngine --filter weakFundE1SettlesUnderBassPolicy`
Expected: FAIL on the inert policy (low retention and/or σ over 0.30). If it unexpectedly PASSES, the synthetic E1 already settles — record that in `bass-baseline.md`, relax the demonstration to the harder B0 (30.87 Hz) or a lower `fundamentalLevel` (e.g. 0.05), and proceed (the geometry change is still correct for real DI).

- [ ] **Step 3: Apply the first-hypothesis geometry change**

In `DetectionPolicy.swift`, replace the `bass` definition's aliased `bands`/`acquire` with an explicit bass plan: give the `low` band the **8192/2048** long window (so E1/A1/D2 all get the long window) and make `acquire` the long window for octave-safe cold start. Keep `high`/`mid` at guitar geometry (bass rarely goes there, and short windows there are fine):

```swift
    public static let bass: DetectionPolicy = {
        let high = BandSpec(window: 1024, hop: 256, floorHz: 250, hysteresisHz: 15,
                            sustainConfidence: 0.6, lockConfidence: 0.90, label: "high")
        let mid = BandSpec(window: 2048, hop: 512, floorHz: 120, hysteresisHz: 10,
                           sustainConfidence: 0.6, lockConfidence: 0.90, label: "mid")
        // Long window down to 40 Hz so E1/A1/D2 get ~7+ periods (was guitar's 4096).
        let low = BandSpec(window: 8192, hop: 2048, floorHz: 40, hysteresisHz: 5,
                           sustainConfidence: 0.6, lockConfidence: 0.75, label: "low")
        let ultralow = BandSpec(window: 8192, hop: 2048, floorHz: 0, hysteresisHz: 0,
                                sustainConfidence: 0.6, lockConfidence: 0.75, label: "ultralow")
        let acquire = BandSpec(window: 8192, hop: 2048, floorHz: 0, hysteresisHz: 0,
                               sustainConfidence: 0.6, lockConfidence: 0.75, label: "acquire")
        return DetectionPolicy(
            searchRange: 25...420, bands: [high, mid, low, ultralow], acquire: acquire,
            smoothingAlpha: AnalysisConfig.smoothingAlpha,
            smoothingMedianCount: AnalysisConfig.smoothingMedianCount,
            emitFloor: AnalysisConfig.emitFloor
        )
    }()
```

- [ ] **Step 4: Re-run the settle test + benchmark, iterate if needed**

Run: `swift test --package-path Packages/TunerEngine --filter weakFundE1SettlesUnderBassPolicy`
Expected: PASS. If retention is still short, the hop may be too coarse — try `low`/`acquire` hop 1024 (more frequent analysis at the cost of CPU) before changing anything shared.
Run: `swift run -c release --package-path Packages/TunerEngine Benchmark --method mpm 2>/dev/null` and confirm in the "Bass policy" section that `bass-weak-fund` retention rose and lock σ fell vs. `bass-baseline.md`, with **lock drops not increased** and **no octave errors**.

- [ ] **Step 5: Update the policy unit test + confirm guitar untouched**

Add to `DetectionPolicyTests.swift`:

```swift
@Test func bassUsesLongWindowDownTo40Hz() {
    let p = DetectionPolicy.bass
    #expect(p.band(forFrequency: 55).window == 8192, "A1 uses the long window")
    #expect(p.band(forFrequency: 41).window == 8192, "E1 uses the long window")
    #expect(p.acquire.window == 8192, "cold start is octave-safe")
    // Guitar is unchanged.
    #expect(DetectionPolicy.fullRange.band(forFrequency: 55).window == 4096)
}
```

Run: `swift test --package-path Packages/TunerEngine`
Expected: PASS — crucially `guitarClampMatchesFullRangeOnGuitarNotes` and `fullRangeMatchesLegacyConstants` stay green (guitar zero-delta).

- [ ] **Step 6: Commit**

```bash
git add Packages/TunerEngine/Sources/TunerEngine/DSP/DetectionPolicy.swift Packages/TunerEngine/Tests/TunerEngineTests/
git commit -m "feat(dsp): bass band geometry — long window down to 40 Hz for E1/A1

Co-Authored-By: Claude Opus 4.8 (1M context) <noreply@anthropic.com>"
```

---

### Task 6: Tune bass per-band `sustainConfidence` / `lockConfidence`

RC2's *safe* lever: lower the bass low/ultralow `sustainConfidence` so weak-fundamental clarity dips don't break the sustain streak (which resets `phaseIntegrator`), without admitting noise. `lockConfidence` (App-layer strobe freeze) can drop slightly to reduce visible flicker — note it does **not** show in the headless benchmark.

**Files:**
- Modify: `Packages/TunerEngine/Sources/TunerEngine/DSP/DetectionPolicy.swift` (`static let bass` low/ultralow/acquire bands)
- Test: `Packages/TunerEngine/Tests/TunerEngineTests/DetectionPolicyTests.swift` (and re-use Task 5's settle test as the acceptance check)

**Interfaces:**
- Consumes: Task 5's bass geometry.
- Produces: tuned bass `sustainConfidence`/`lockConfidence` (bass-isolated).

- [ ] **Step 1: Write the failing floor test**

Add to `DetectionPolicyTests.swift`:

```swift
@Test func bassLowensSustainFloorForWeakFundamentals() {
    let p = DetectionPolicy.bass
    // Bass low/ultralow sustain floor is relaxed below guitar's 0.6 so weak-fund
    // clarity dips don't shatter the lock streak.
    #expect(p.sustainConfidence(forFrequency: 41) < 0.6)
    #expect(p.sustainConfidence(forFrequency: 31) < 0.6)
    // Guitar floor is unchanged.
    #expect(DetectionPolicy.fullRange.sustainConfidence(forFrequency: 41) == 0.6)
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `swift test --package-path Packages/TunerEngine --filter bassLowensSustainFloorForWeakFundamentals`
Expected: FAIL (bass sustain floor is still 0.6 after Task 5).

- [ ] **Step 3: Apply the first-hypothesis floor change**

In the `bass` definition (Task 5), change the `low`, `ultralow`, and `acquire` bands' `sustainConfidence` from `0.6` to `0.55` and `lockConfidence` from `0.75` to `0.70`. Leave `high`/`mid` at guitar values. Keep the `emitFloor` at `AnalysisConfig.emitFloor` (0.5) — do **not** raise it here (that is the Phase 2 decision).

- [ ] **Step 4: Re-run acceptance + guard the octave invariant**

Run: `swift test --package-path Packages/TunerEngine --filter "bassLowensSustainFloorForWeakFundamentals|weakFundE1SettlesUnderBassPolicy"`
Expected: PASS.
Run: `swift run -c release --package-path Packages/TunerEngine Benchmark --method mpm 2>/dev/null` and confirm the headline **octave-error rate stays 0.00%**, stress octave errors stay 0, and `bass-weak-fund` retention is ≥ the Task 5 number. If octave errors appear, the floor is too low — back off toward 0.58 and re-measure; if it still won't settle, that is a signal for the Phase 2 decision gate.

- [ ] **Step 5: Run the full suite**

Run: `swift test --package-path Packages/TunerEngine`
Expected: PASS (guitar zero-delta tests included).

- [ ] **Step 6: Commit**

```bash
git add Packages/TunerEngine/Sources/TunerEngine/DSP/DetectionPolicy.swift Packages/TunerEngine/Tests/TunerEngineTests/DetectionPolicyTests.swift
git commit -m "feat(dsp): relax bass low/ultralow sustain & lock floors for weak fundamentals

Co-Authored-By: Claude Opus 4.8 (1M context) <noreply@anthropic.com>"
```

---

## Phase 1.5 — Decision gate

### Task 7: Measure and decide whether Phase 2 (shared code) is needed

**Files:**
- Modify: `docs/superpowers/specs/2026-06-18-bass-detection-policy-tuning-design.md` (append a "Decision gate (2026-..)" subsection recording the measured outcome and the decision)

**Interfaces:**
- Consumes: post-Phase-1 benchmark numbers vs. `bass-baseline.md`.

- [ ] **Step 1: Re-run the benchmark and compare to baseline + success criteria**

Run: `swift run -c release --package-path Packages/TunerEngine Benchmark --method mpm 2>/dev/null`
Record: `bassLockSigma`, `bassLockRetention`, `bassLockDrops`, octave-error rate, stress octave errors, `lockMSMedian` (timeToLock).

- [ ] **Step 2: Apply the decision rule and document it**

Append the outcome to the spec. Decide:
- **All success criteria met** (bass weak-fund retention ≥ 0.85, lock σ < 0.30, octave 0.00%, guitar unchanged, timeToLock within bound) → **skip Phase 2**, go to Task 10.
- **Lock still shatters** (retention low / drops > 0) despite the sustain floor → do **Task 9** (phase-integrator grace period, shared).
- **Noise/octave errors crept in**, or noise rejection needs `emitFloor` > 0.5 → do **Task 8** (octave-rescue floor decoupling, shared).

Write the chosen branch and the numbers that justify it into the spec.

- [ ] **Step 3: Commit**

```bash
git add docs/superpowers/specs/2026-06-18-bass-detection-policy-tuning-design.md
git commit -m "docs(spec): bass tuning decision gate — record Phase 1 result + Phase 2 decision

Co-Authored-By: Claude Opus 4.8 (1M context) <noreply@anthropic.com>"
```

---

## Phase 2 — Shared-code changes (CONDITIONAL — only the branch the gate selected)

### Task 8 (conditional): Decouple the octave-rescue floor from `emitFloor`

Do this **only if** Task 7 selected the noise/`emitFloor` branch. `PitchDetector.hybrid` reuses `emitFloor` as the octave-rescue bar (`lower.clarity > emitFloor ? lower : higher`, PitchDetector.swift:187). Raising bass `emitFloor` for noise rejection would push the rescue toward the octave candidate — against the 0.00% octave spec. Add a dedicated `octaveRescueFloor` defaulting to 0.5.

**Files:**
- Modify: `Packages/TunerEngine/Sources/TunerEngine/DSP/PitchDetector.swift` (`detect`, `hybrid`)
- Modify: `Packages/TunerEngine/Sources/TunerEngine/Pipeline/PitchPipeline.swift` (the `PitchDetector.detect(...)` call at line 133)
- Test: `Packages/TunerEngine/Tests/TunerEngineTests/PitchDetectorTests.swift`

**Interfaces:**
- Produces: `PitchDetector.detect(..., emitFloor:octaveRescueFloor:)` and `hybrid(..., octaveRescueFloor: Double = AnalysisConfig.emitFloor)`; the octave-rescue pick uses `octaveRescueFloor`, the emit gate keeps `emitFloor`.

- [ ] **Step 1: Write the failing routing test**

Add to `PitchDetectorTests.swift` (this is the routing test deferred from Slice 1 Task 2 — it must flip the pick):

```swift
@Test func octaveRescueFloorRoutesIndependentlyOfEmitFloor() throws {
    // An octave-ambiguous inharmonic low tone where MPM/YIN can disagree by an octave.
    let frame = string(55.0, 4096)   // A1
    // A low rescue floor trusts the lower fundamental; a high one forces the octave.
    let lowFloor = try #require(PitchDetector.detect(frame, sampleRate: fs, range: range,
                                                     method: .hybrid, octaveRescueFloor: 0.0))
    let highFloor = try #require(PitchDetector.detect(frame, sampleRate: fs, range: range,
                                                      method: .hybrid, octaveRescueFloor: 1.0))
    // With octaveRescueFloor decoupled, the emit gate (emitFloor) does not move the pick.
    #expect(lowFloor.frequency <= highFloor.frequency + 1e-6,
            "low rescue floor must not pick a higher (octave) candidate than the high floor")
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `swift test --package-path Packages/TunerEngine --filter octaveRescueFloorRoutesIndependentlyOfEmitFloor`
Expected: FAIL — `extra argument 'octaveRescueFloor'`.

- [ ] **Step 3: Add the parameter and use it in the rescue**

In `PitchDetector.swift`, add `octaveRescueFloor: Double = AnalysisConfig.emitFloor` to `detect` and `hybrid`. In `detect`, pass it to the `.hybrid` case. In `hybrid`, replace the rescue line and its NOTE comment:

```swift
            // Octave-rescue trust bar — decoupled from the per-instrument emit gate
            // so a higher bass emitFloor (noise rejection) cannot bias the pick toward
            // the octave (preserves the 0.00% octave-error spec).
            let pick = lower.clarity > octaveRescueFloor ? lower : higher
```

- [ ] **Step 4: Thread it from the pipeline (default keeps guitar zero-delta)**

In `PitchPipeline.swift`'s `analyze()`, pass `octaveRescueFloor: AnalysisConfig.emitFloor` explicitly in the `PitchDetector.detect(...)` call (so bass's raised `emitFloor` does not touch the rescue):

```swift
        guard let det = PitchDetector.detect(
            frame, sampleRate: sampleRate, range: policy.searchRange,
            method: method, emitFloor: policy.emitFloor,
            octaveRescueFloor: AnalysisConfig.emitFloor
        ), det.clarity >= policy.emitFloor else {
```

- [ ] **Step 5: (Same task) raise bass `emitFloor` to the value the gate selected**

In `DetectionPolicy.bass`, set `emitFloor` to the noise-rejecting value Task 7 justified (e.g. `0.6`). Re-run the bench: bass noise robustness improves, octave-error stays 0.00%.

- [ ] **Step 6: Run the routing test + full suite + benchmark**

Run: `swift test --package-path Packages/TunerEngine`
Expected: PASS (including `detectAcceptsEmitFloorAndDefaultsToLegacy`, `guitarClampMatchesFullRangeOnGuitarNotes`).
Run: `swift run -c release --package-path Packages/TunerEngine Benchmark --method mpm 2>/dev/null` — octave-error rate 0.00%, stress octave errors 0.

- [ ] **Step 7: Commit**

```bash
git add Packages/TunerEngine/Sources/TunerEngine/DSP/PitchDetector.swift Packages/TunerEngine/Sources/TunerEngine/Pipeline/PitchPipeline.swift Packages/TunerEngine/Sources/TunerEngine/DSP/DetectionPolicy.swift Packages/TunerEngine/Tests/TunerEngineTests/PitchDetectorTests.swift
git commit -m "feat(dsp): decouple octave-rescue floor from emitFloor; raise bass emitFloor

Co-Authored-By: Claude Opus 4.8 (1M context) <noreply@anthropic.com>"
```

---

### Task 9 (conditional): Phase-integrator grace period before reset

Do this **only if** Task 7 selected the lock-shatter branch. `PitchPipeline.process` calls `phaseIntegrator.reset()` on every non-stable frame (line 247), so a single sub-floor frame shatters a held lock. Add a small grace counter so an isolated dip doesn't reset. **Shared code → guitar guard required.**

**Files:**
- Modify: `Packages/TunerEngine/Sources/TunerEngine/Pipeline/PitchPipeline.swift` (`analyze`, new instance counter)
- Test: `Packages/TunerEngine/Tests/TunerEngineTests/PipelineTests.swift`

**Interfaces:**
- Produces: `PitchPipeline` private `unstableStreak: Int` and a `lockGraceFrames` constant in `AnalysisConfig`; reset only after the streak exceeds the grace.

- [ ] **Step 1: Write the failing guitar-guard + bass-improvement test**

Add to `PipelineTests.swift`:

```swift
@Test func graceDoesNotChangeGuitarLockBehavior() throws {
    // Guitar zero-delta: a clean G3 still locks and reads identically.
    let rs = steady(run(Synth.harmonic(fundamental: 196, sampleRate: fs, seconds: 1.2)))
    let last = try #require(rs.last)
    #expect(last.note.description == "G3")
    #expect(abs(last.cents) < 1.0)
}
```

(The bass-improvement acceptance is `weakFundE1SettlesUnderBassPolicy` from Task 5 reaching retention ≥ 0.85, which this change must push over the line.)

- [ ] **Step 2: Run to verify the guard passes today (baseline) and bass still fails**

Run: `swift test --package-path Packages/TunerEngine --filter "graceDoesNotChangeGuitarLockBehavior|weakFundE1SettlesUnderBassPolicy"`
Expected: guard PASS, bass settle test FAIL (the reason we're in this branch).

- [ ] **Step 3: Add the grace constant and counter**

In `AnalysisConfig.swift` (gate section):

```swift
    /// Consecutive non-stable frames tolerated before the phase-integrator lock
    /// is dropped — prevents a single clarity dip from shattering a held lock.
    public static let lockGraceFrames: Int = 2
```

In `PitchPipeline.swift`, add `private var unstableStreak = 0`, reset it to 0 in `reset()`/`setPolicy()`, and replace the `else { phaseIntegrator.reset() }` block in `analyze()`:

```swift
        } else {
            unstableStreak += 1
            if unstableStreak > AnalysisConfig.lockGraceFrames { phaseIntegrator.reset() }
        }
```

and set `unstableStreak = 0` inside the `if stable {` branch.

- [ ] **Step 4: Run acceptance + full suite**

Run: `swift test --package-path Packages/TunerEngine`
Expected: PASS — `weakFundE1SettlesUnderBassPolicy` now meets retention ≥ 0.85, and **all guitar tests stay green** (`graceDoesNotChangeGuitarLockBehavior`, `tracksCleanGuitarNote`, `steadyToneIsLowJitter`, `guitarClampMatchesFullRangeOnGuitarNotes`).
Run: `swift run -c release --package-path Packages/TunerEngine Benchmark --method mpm 2>/dev/null` — confirm guitar headline numbers (clean abs, lock σ, bass abs) are unchanged within float tolerance and octave-error stays 0.00%.

- [ ] **Step 5: Commit**

```bash
git add Packages/TunerEngine/Sources/TunerEngine/DSP/AnalysisConfig.swift Packages/TunerEngine/Sources/TunerEngine/Pipeline/PitchPipeline.swift Packages/TunerEngine/Tests/TunerEngineTests/PipelineTests.swift
git commit -m "feat(dsp): phase-integrator grace period so a single dip won't shatter lock

Co-Authored-By: Claude Opus 4.8 (1M context) <noreply@anthropic.com>"
```

---

## Phase 3 — App layer: flip bass to `.lock` + fix the `setInstrument` gap

### Task 10: Bass `defaultMode = .lock` and route `setInstrument` so it arms the target

`InstrumentProfile.builtIn(.bass)` defaults to `.auto`; flipping to `.lock` exposes the `setInstrument` gap — it assigns `mode = profile.defaultMode` directly (bypassing `setMode`'s `activeIdx` arming) and then `setTuning` → `updateTarget` runs with a nil `activeIdx`, leaving `targetNote == nil` and a chromatic strobe.

**Files:**
- Modify: `App/Engine/InstrumentProfile.swift` (bass `defaultMode`)
- Modify: `App/Engine/LiveTunerModel.swift` (`setInstrument`, lines 173-183)
- Test: `LUMA/Tests/InstrumentProfileTests.swift` (update `bassProfileStaysAutoInSlice1`), `LUMA/Tests/LiveTunerModelProfileTests.swift` (new test)

**Interfaces:**
- Consumes: `LiveTunerModel.setMode`, `.setTuning`, `.targetNote`, `.mode`, `.activeIdx` (all `@testable`-visible internals).
- Produces: bass profile `defaultMode == .lock`; `setInstrument` ordering that arms `activeIdx` to the lowest string of the *new* tuning.

- [ ] **Step 1: Write the failing tests**

Update `bassProfileStaysAutoInSlice1` in `InstrumentProfileTests.swift` (rename + flip the assertion):

```swift
@Test func bassProfileDefaultsToLock() {
    let p = InstrumentProfile.builtIn(.bass)
    #expect(p.id == .bass)
    #expect(p.detection == DetectionPolicy.bass)
    #expect(p.defaultTuning.id == Tunings.bass.id)
    #expect(p.defaultMode == .lock)   // bass-fix flips this from .auto
}
```

Add to `LiveTunerModelProfileTests.swift`:

```swift
@Test func switchingToBassArmsLockTarget() {
    let model = LiveTunerModel()
    model.setInstrument(.bass)
    #expect(model.mode == .lock, "bass defaults to string-lock")
    let lowest = model.tuning.strings.first
    #expect(lowest != nil)
    // .lock must arm the lowest string so the strobe judges a target, not chromatic.
    #expect(model.targetNote == lowest.map { Note(midi: $0.midi) },
            "lock target armed to the lowest bass string after instrument switch")
}
```

- [ ] **Step 2: Run to verify they fail**

Build + test the App target (these are `LUMATests`, not `swift test`):
Run: `xcodegen generate` (if `project.yml` changed; harmless otherwise) then the `LUMA` scheme tests via Xcode (`BuildProject` + run `LUMATests`, or `xcodebuild test -scheme LUMA -destination 'platform=iOS Simulator,name=iPhone 15'`).
Expected: FAIL — `bassProfileDefaultsToLock` (still `.auto`) and `switchingToBassArmsLockTarget` (`targetNote` nil).

- [ ] **Step 3: Flip the bass default**

In `InstrumentProfile.swift`, change the bass case:

```swift
        case .bass:
            return InstrumentProfile(
                id: .bass, displayName: "Bass",
                defaultTuning: Tunings.bass, detection: .bass,
                defaultMode: .lock, defaultInput: .di
            )
```

- [ ] **Step 4: Fix `setInstrument` ordering so the target arms**

In `LiveTunerModel.swift`, rewrite `setInstrument` so the new tuning is in place *before* the mode is applied through `setMode` (which arms `activeIdx`), and input through `setInputKind`:

```swift
    func setInstrument(_ newValue: Instrument) {
        guard newValue != profile.id else { return }
        profile = .builtIn(newValue)
        let e = engine
        let pol = profile.detection
        Task { await e.setDetectionPolicy(pol) }
        setTuning(profile.defaultTuning)         // new tuning first (validates/clears activeIdx)
        setMode(profile.defaultMode)             // arms activeIdx to lowest string when .lock
        setInputKind(profile.defaultInput)       // pushes input preference + restart status
        lastInstrument = newValue.rawValue
    }
```

Note: `setInputKind` early-returns when `kind == inputKind`, so a same-input switch is a no-op (correct). `setMode` calls `updateTarget()`, so the chromatic-vs-locked target is recomputed after the tuning swap.

- [ ] **Step 5: Run the App tests to verify they pass**

Run the `LUMATests` again (Xcode / `xcodebuild test -scheme LUMA ...`).
Expected: PASS — including the existing `setInstrumentSwapsProfileAndTuning`, `lockFloorComesFromActiveProfile`, `restoresPersistedInstrumentAndTuning` (confirm the reordering didn't break persistence/restore).

- [ ] **Step 6: Commit**

```bash
git add App/Engine/InstrumentProfile.swift App/Engine/LiveTunerModel.swift LUMA/Tests/InstrumentProfileTests.swift LUMA/Tests/LiveTunerModelProfileTests.swift
git commit -m "feat(app): bass defaults to .lock; setInstrument arms lock target via setMode

Co-Authored-By: Claude Opus 4.8 (1M context) <noreply@anthropic.com>"
```

---

## Phase 4 — Lock in the gate + re-baseline

### Task 11: Add the bass-stability CI gate with an empirical threshold

**Files:**
- Modify: `Packages/TunerEngine/Sources/Benchmark/main.swift` (the `--ci` gate block)

**Interfaces:**
- Consumes: `Summary.bassLockSigma`, `.bassLockRetention`, `.bassLockDrops` (Task 3).

- [ ] **Step 1: Read the tuned numbers**

Run: `swift run -c release --package-path Packages/TunerEngine Benchmark --method mpm 2>/dev/null`
Record the tuned `bassLockSigma`, `bassLockRetention`, `bassLockDrops`.

- [ ] **Step 2: Add the gate with threshold = tuned number + margin**

In `main.swift`, inside `if flag("--ci")`, add (use the *measured* tuned values; the constants below are illustrative — set them from Step 1 with margin, and never tighter than the achieved number):

```swift
    // Bass-settling gates (bass notes under .bass). Thresholds = tuned result + margin;
    // ratcheted, never red-lighting on landing (see docs/benchmarks/bass-baseline.md).
    if s.bassLockSigma > 0.30 { failures.append("bass lock σ \(s.bassLockSigma)¢ > 0.30") }
    if s.bassLockRetention < 0.80 { failures.append("bass lock retention \(s.bassLockRetention) < 0.80") }
    if s.bassLockDrops > 2 { failures.append("bass lock drops \(s.bassLockDrops) > 2") }
```

Add bass numbers to the success-log line so CI logs show them.

- [ ] **Step 3: Run the CI gate locally to confirm it passes**

Run: `swift run -c release --package-path Packages/TunerEngine Benchmark --ci 2>&1 | tail -5`
Expected: `benchmark CI gate passed (...)`, exit 0. If it fails, the thresholds are tighter than achieved — relax to the measured value + margin (do not loosen the hard octave invariants).

- [ ] **Step 4: Commit**

```bash
git add Packages/TunerEngine/Sources/Benchmark/main.swift
git commit -m "feat(bench): CI gate on bass lock σ/retention/drops (empirical threshold)

Co-Authored-By: Claude Opus 4.8 (1M context) <noreply@anthropic.com>"
```

---

### Task 12: Re-baseline `accuracy.md`, confirm guitar unchanged, archive the todos

**Files:**
- Modify: `docs/benchmarks/accuracy.md` (regenerated)
- Modify (git mv): `docs/todos/P1-bass-detection-policy-tuning.md`, `docs/todos/P1-bass-settle-stability-harness.md` → `docs/todos/archive/`

**Interfaces:**
- Consumes: the final tuned engine.

- [ ] **Step 1: Regenerate the published accuracy report**

Run: `swift run -c release --package-path Packages/TunerEngine Benchmark --out docs/benchmarks --date "Generated 2026-06-18"`
This rewrites `docs/benchmarks/accuracy.md` + `.csv`.

- [ ] **Step 2: Confirm guitar headline numbers did not move**

Compare the regenerated `accuracy.md` headline + "By range" guitar/mid/high rows against the previous committed copy (`git diff docs/benchmarks/accuracy.md`). Expected: guitar/mid/high values unchanged within float tolerance; only the new "Bass policy" section and any improved bass rows differ. If a guitar number moved, a shared-code change leaked — stop and investigate before continuing.

- [ ] **Step 3: Run the full test matrix one last time**

Run: `swift test --package-path Packages/TunerEngine` → PASS.
Run the `LUMATests` via Xcode → PASS.
Run: `swift run -c release --package-path Packages/TunerEngine Benchmark --ci 2>&1 | tail -3` → gate passed, exit 0.

- [ ] **Step 4: Archive the completed todos**

```bash
git mv docs/todos/P1-bass-detection-policy-tuning.md docs/todos/archive/
git mv docs/todos/P1-bass-settle-stability-harness.md docs/todos/archive/
```

Add a one-line completion note to the top of each archived file referencing this plan and the merge.

- [ ] **Step 5: Commit**

```bash
git add docs/benchmarks/accuracy.md docs/benchmarks/accuracy.csv docs/todos/
git commit -m "docs: re-baseline accuracy.md (bass), archive completed P1 bass todos

Co-Authored-By: Claude Opus 4.8 (1M context) <noreply@anthropic.com>"
```

---

## Self-Review (completed)

**Spec coverage:** Phase 0 policy-aware harness → Tasks 1,3. Lock-retention/drop ruler → Task 2. Baseline → Task 4. Bass-isolated levers (bands/acquire, confidence) → Tasks 5,6. Conditional emitFloor decoupling → Task 8. Conditional grace period → Task 9. Decision gate → Task 7. App-layer `.lock` + `setInstrument` fix → Task 10. CI gate (empirical) → Task 11. Re-baseline + guitar-unchanged + archive → Task 12. `searchRange` (already `25...420`) needs no task. All spec sections map to a task.

**Placeholder scan:** Empirical tuning tasks (5,6) carry concrete first-hypothesis edits, fixed acceptance thresholds, and an explicit "if baseline already passes, record and keep minimal" instruction — not TBDs. Task 11's gate constants are explicitly flagged as "set from the measured tuned value + margin," which is a data dependency, not a placeholder.

**Type consistency:** `policy: DetectionPolicy = .fullRange` (Task 1) is consumed by Tasks 3,5. `CaseResult.lockRetention`/`.lockDrops` and `CaseRunner.lockTrajectory` (Task 2) are consumed by Task 3's aggregation. `Summary.bassLockSigma`/`.bassLockRetention`/`.bassLockDrops`/`.bassPolicyCases` (Task 3) are consumed by Task 11's gate. `octaveRescueFloor` default `AnalysisConfig.emitFloor` (Task 8) is threaded from `PitchPipeline.analyze`. `setMode`/`setTuning`/`setInputKind` (Task 10) match the existing `LiveTunerModel` signatures.
