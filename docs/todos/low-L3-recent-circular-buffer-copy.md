# recent() circular-buffer copy is a scalar element-at-a-time loop

**Severity:** Low  
**Audit:** 2026-06-15-full  
**Domain:** dsp

## Problem

Copies up to 8192 samples one element at a time. Non-wrapping case should use a contiguous copy; wrapping case should use two contiguous `vDSP` copies.

## Fix

- Use `cblas_scopy`, `Array.replaceSubrange`, or two contiguous `vDSP` copies for the wrap case
- Benchmark to verify no performance regression
- Add a comment documenting the circular-buffer copy logic

## Files

- `Packages/TunerEngine/Sources/TunerEngine/Pipeline/PitchPipeline.swift` (line 274)
