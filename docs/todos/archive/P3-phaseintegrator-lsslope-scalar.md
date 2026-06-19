---
priority: P3
status: wont-do
domain: dsp
source: 2026-06-15-full audit (L2), re-scoped 2026-06-18 sweep
resolved: 2026-06-18 — closed as won't-do (see Resolution)
---

# PhaseIntegrator.lsSlope — centering/means still scalar (vDSP partial)

## Resolution (2026-06-18): WON'T-DO

Closed without the change. Rationale:

- **Net perf loss, not win.** Arrays are k ≤ 140 and off the hot path; the vDSP call
  overhead (`vDSP_meanvD`, `vDSP_vsaddD`) exceeds the scalar `.reduce`/`.map` cost at
  these sizes. The todo itself rated this "very low value."
- **Breaks the byte-identical benchmark proof for zero benefit.** `reduce(0,+)` →
  `vDSP_meanvD` changes summation order, so the mean (which feeds centering → slope →
  `precisionCents`/`emittedFrequency`) shifts by ~1 ULP and the CI-gated accuracy.csv is
  no longer byte-identical. (`vDSP_vsaddD` centering alone *would* be bit-identical since
  `a + (-tMean) == a - tMean` in IEEE — but half-vectorizing a function for a consistency
  nit is worse than leaving it.)
- The `sxy`/`sxx`/SSE dot products are already vDSP (`c85720e`); the dominant arithmetic
  is done. The residual is a consistency nit, not correctness or perf.

Disposition agreed: not worth the risk/churn. Archived for the record.

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
