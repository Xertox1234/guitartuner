# Autocorrelation prefix-energy uses scalar loop; vDSP_vsq available

**Severity:** Low  
**Audit:** 2026-06-15-full  
**Domain:** dsp

## Problem

Prefix sum-of-squares is computed via scalar `v*v` loop. `vDSP_vsq` + scalar cumsum would vectorize the squaring step. Minor relative to the O(N²/2) per-lag `vDSP_dotpr` cost.

## Fix

- Replace scalar squaring loop with `vDSP_vsq`
- Use `vDSP_svemul` or accumulation on the squared result
- Benchmark to verify no regression (likely negligible impact)

## Files

- `Packages/TunerEngine/Sources/TunerEngine/DSP/Autocorrelation.swift` (line 47)
