# No post-NSDF octave-history guard — single point of octave safety

**Severity:** Medium  
**Audit:** 2026-06-15-full  
**Domain:** dsp

## Problem

`PitchPipeline` stores `trackedFrequency` but never checks the NSDF-detected frequency against it before proceeding to refinement. The only defense against an octave jump is the `k = 0.9` threshold. The architecture has no secondary recovery for pathological real-world signals not in the benchmark suite.

## Fix

- Add a post-NSDF octave-history guard: `|1200·log2(f/tracked)| > 1200 && clarity < 0.95 → handleUnvoiced()`
- Document the octave-safety chain in a comment above the check
- Test the guard with synthetic pathological signals (octave aliases, weak fundamentals)

## Files

- `Packages/TunerEngine/Sources/TunerEngine/DSP/PitchDetector.swift` (line 91)
- `Packages/TunerEngine/Sources/TunerEngine/Pipeline/PitchPipeline.swift`
