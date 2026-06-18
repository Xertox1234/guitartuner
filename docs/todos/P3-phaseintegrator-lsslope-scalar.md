---
priority: P3
status: partial
domain: dsp
source: 2026-06-15-full audit (L2), re-scoped 2026-06-18 sweep
---

# PhaseIntegrator.lsSlope — centering/means still scalar (vDSP partial)

**Severity:** Low
**Audit:** 2026-06-15-full · **Re-scoped:** 2026-06-18 backlog sweep
**Domain:** dsp

## Status: PARTIAL

The `sxy`/`sxx` dot products were vectorized with `vDSP_dotprD`/`vDSP_vsmaD`
(commit `c85720e`) — the dominant arithmetic is done. **Still scalar:** the
centering (`.map { $0 - tMean }`) and the means (`.reduce`), which the original
todo also called for via `vDSP_vsubD`. Kept open so the residual isn't silently
absorbed into "done".

## Remaining fix

- Replace the centering `.map { $0 - tMean }` with `vDSP_vsaddD` (add `-tMean`)
  or `vDSP_vsbsmD`, and the `.reduce` means with `vDSP_meanvD`.
- Very low value: arrays are small (k ≤ 140) and this is not on the hot path;
  it is a consistency/vDSP-rule nit, not a perf win. Fine to drop if cleaning house.
- Benchmark zero-delta required (CI-gated DSP path) before committing.

## Files

- `Packages/TunerEngine/Sources/TunerEngine/DSP/PhaseIntegrator.swift` (centering/means near the lsSlope dot products, ~line 260)
