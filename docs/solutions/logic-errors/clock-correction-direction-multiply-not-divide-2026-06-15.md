---
title: "Fast crystal under-reports frequency — apply correctionFactor by multiplying, not dividing"
track: bug
category: logic-errors
tags: [capture, pipeline, dsp]
module: TunerEngine, App
applies_to: ["App/Engine/LiveTunerModel.swift", "Packages/TunerEngine/Sources/TunerEngine/Capture/ClockCalibration.swift"]
created: 2026-06-15
---

## Symptom

Clock correction code divides measured frequency by `correctionFactor`, doubling the error instead of removing it. The bug is silent: at 44 ppm the uncorrected bias is ~0.076 ¢; the wrong-direction correction moves it to ~0.152 ¢ in the opposite direction.

## Root cause

Intuition says "fast crystal → higher clock rate → measured frequency is too high → divide to correct." This is wrong. The pipeline samples audio at the *nominal* rate (e.g. 48000 Hz assumed per sample). A fast crystal delivers *more* samples per real second than nominal. For a true tone at `f_true`:

- Samples per cycle = `actualRate / f_true` = `nominalRate * (1 + ppm/1e6) / f_true`
- Pipeline computes: `f_meas = nominalRate / samplesPerCycle = f_true / (1 + ppm/1e6) = f_true / cf`
- Therefore: `f_true = f_meas * cf` — **multiply**

A fast crystal packs more samples into each real-world second, making periods appear shorter than they are, so the sample-domain frequency is **under-estimated**. Dividing by `cf` (>1) makes it even lower — the opposite of the correction needed.

## Fix

```swift
// Wrong — doubles the error:
let adjFreq = r.frequency / correctionFactor

// Correct:
let adjFreq = r.frequency * correctionFactor
let centsShift = 1200.0 * log2(correctionFactor)   // positive when crystal runs fast
cents = r.cents + centsShift                        // add (measured was too low)
```

## Why it was wrong

The direction of the crystal error at the physics layer (more clock ticks) and its effect at the sample-domain layer (lower reported frequency) are opposite, which defeats naive intuition. The `correctionFactor` API doc describes a *playback* direction ("multiply nominal by cf to get actual device rate"), but for *measurement correction* the inverse consumer logic applies.

## Related files

- `App/Engine/LiveTunerModel.swift` — where correction is applied in `apply()`
- `Packages/TunerEngine/Sources/TunerEngine/Capture/ClockCalibration.swift` — `correctionFactor` definition
- `Packages/TunerEngine/Tests/TunerEngineTests/ClockCalibrationTests.swift` — test comment updated to state the correct direction
