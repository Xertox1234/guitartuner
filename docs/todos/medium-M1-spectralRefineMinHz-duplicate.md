# spectralRefineMinHz duplicates AnalysisConfig.midLowHz

**Severity:** Medium  
**Audit:** 2026-06-15-full  
**Domain:** dsp

## Problem

`PitchPipeline` declares `static let spectralRefineMinHz: Double = 120` independently of `AnalysisConfig.midLowHz = 120`. Both represent the same physical boundary. If either is changed independently, the refine path and the window-band selection will disagree. AnalysisConfig must be the single source of truth.

## Fix

- Remove `spectralRefineMinHz` from `PitchPipeline`
- Replace all references with `AnalysisConfig.midLowHz`
- Add a comment in `AnalysisConfig` documenting that this constant also gates spectral refinement

## Files

- `Packages/TunerEngine/Sources/TunerEngine/Pipeline/PitchPipeline.swift` (line 43)
- `Packages/TunerEngine/Sources/TunerEngine/AnalysisConfig.swift`
