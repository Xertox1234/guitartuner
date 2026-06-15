# Multiple load-bearing gate thresholds hardcoded outside AnalysisConfig

**Severity:** Medium  
**Audit:** 2026-06-15-full  
**Domain:** dsp

## Problem

Five accuracy-critical tuning constants are scattered outside `AnalysisConfig`: `lockPrecisionThreshold = 1.0`, `SustainGate(minConfidence: 0.6)`, `emitFloor = 0.5`, `alpha = 0.35`, `snapCents = 120`, and `k = 0.9` (NSDF peak-selection). Inlining them makes test overrides and cross-constant reasoning fragile.

## Fix

- Collect all five thresholds into `AnalysisConfig` as documented constants
- Replace inline values with named references
- Add a section in `AnalysisConfig` documenting the role of each threshold in the lock/gate chain

## Files

- `Packages/TunerEngine/Sources/TunerEngine/Pipeline/PitchPipeline.swift` (line 37)
- `Packages/TunerEngine/Sources/TunerEngine/DSP/Smoothing.swift`
- `Packages/TunerEngine/Sources/TunerEngine/DSP/PitchDetector.swift` (line 91)
- `Packages/TunerEngine/Sources/TunerEngine/AnalysisConfig.swift`
