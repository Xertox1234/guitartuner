# PhaseIntegrator.lsSlope hand-rolled Double loops; vDSP_dotprD available

**Severity:** Low  
**Audit:** 2026-06-15-full  
**Domain:** dsp

## Problem

`sxy`/`sxx` dot products and centring are computed via scalar O(k) loops (k ≤ 140). Low arithmetic volume but violates the vDSP rule.

## Fix

- Use `vDSP_dotprD` for dot product computation
- Use `vDSP_vsubD` or `vDSP_svsubD` for centering operations
- Benchmark to verify no regression

## Files

- `Packages/TunerEngine/Sources/TunerEngine/DSP/PhaseIntegrator.swift` (line 260)
