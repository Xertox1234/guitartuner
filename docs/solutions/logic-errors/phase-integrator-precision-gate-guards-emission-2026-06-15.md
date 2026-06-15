---
title: "PhaseIntegrator precisionCents gate must guard both LOCKED state and emitted frequency"
track: bug
category: logic-errors
tags: [dsp, pipeline]
module: TunerEngine
applies_to: ["Packages/TunerEngine/Sources/TunerEngine/Pipeline/PitchPipeline.swift", "Packages/TunerEngine/Sources/TunerEngine/DSP/PhaseIntegrator.swift"]
created: 2026-06-15
---

## Symptom

Decay-glide stress accuracy regresses severely (mean error 4.21 ¢ → 9.47 ¢) after adding the PhaseIntegrator. The integrator appears to fire correctly and sets `isLockIntegrated = false` during glide — yet the emitted frequency is still wrong.

## Root cause

`PhaseIntegrator.feed()` returns a result (`r.f0`, `r.precisionCents`) whenever it has accumulated `minHops` frames, even during decay-glide attack. The initial implementation used that result unconditionally:

```swift
if let r = phaseIntegrator.feed(...) {
    emittedFrequency = r.f0          // ← WRONG: used even when precisionCents > 1 ¢
    ...
    isLockIntegrated = r.precisionCents <= lockPrecisionThreshold
}
```

During decay-glide, the pitch is drifting exponentially. The LS fit captures the glide *rate* as part of its slope, producing a `f0` biased by the pitch trend — potentially several cents off. `isLockIntegrated` was correctly gated off, but the biased f0 still replaced `smoothed` as the emitted frequency.

The `precisionCents` gate serves **two independent functions**:
1. UX gate — whether to show "LOCKED ±X ¢" to the user
2. DSP gate — whether the integrator's numerical estimate is accurate enough to override `smoothed`

These look like the same gate but have distinct consequences: a false lock declaration is a display bug; an incorrect emitted frequency corrupts the downstream note/cents calculation and any string-lock cents judge.

## Fix

```swift
if let r = phaseIntegrator.feed(...) {
    precisionCents = r.precisionCents
    isLockIntegrated = r.precisionCents <= Self.lockPrecisionThreshold
    if isLockIntegrated {
        emittedFrequency = r.f0          // only use f0 when residuals are tight
        if let (nn, nc) = Pitch.nearest(frequency: r.f0, a4: a4) {
            emittedNearest = nn
            emittedCents = nc
        }
    }
    // When !isLockIntegrated: emittedFrequency stays = smoothed
}
```

## Why it was wrong

The integrator's `precisionCents` property communicates uncertainty, not just state. Large residuals (decay-glide attack, vibrato, noisy signal) mean the LS slope is fitting non-stationary phase — the returned `f0` is unreliable. The fix ensures that the only time the integrator overrides the frequency estimate is when it has genuinely converged on a stationary pitch.

Rule of thumb: **never use an integrator's output as a primary value when its uncertainty metric is above threshold** — gate both the display state and the numeric emission on the same threshold.

## Related files

- `Packages/TunerEngine/Sources/TunerEngine/Pipeline/PitchPipeline.swift` — P3 block in `analyze()`
- `Packages/TunerEngine/Sources/TunerEngine/DSP/PhaseIntegrator.swift` — `Result.precisionCents` definition
- [[phase-integrator-n1-only-design-2026-06-14]] — companion solution for why n=1 only
