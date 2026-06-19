# DSP rules

- Track the **fundamental**, not the tallest FFT peak. Real strings are inharmonic — partials sit sharp of exact integer multiples. MPM/NSDF is correct; naive peak-picking is not.
- Phase-vocoder refinement provides sub-cent precision. The phase advance between hops is simultaneously the strobe phase — same computation, dual output. Do not decouple these.
- Window/hop sizes are **range-dependent** — do not use a single window size for all pitches:
  - high (≥250 Hz): 1024 samples / 256 hop (75% overlap)
  - mid (120–250 Hz): 2048 / 512
  - low (<120 Hz) + cold acquisition: 4096 / 1024
- The bass latency floor is physics, not a bug. Low B (~31 Hz) needs ~2–3 periods to be seen. ~100–150 ms time-to-lock on the lowest strings is correct and documented (DESIGN §3). Do not fight it.
- Gate on the NSDF confidence metric, not on time. Gate on sustained pitch, not on transient attack.
- Smoothing order is median then EMA — in that sequence. Median kills outliers; EMA smooths the result. Do not swap.
- Use Accelerate/vDSP for all inner-loop math. No hand-rolled loops where `vDSP_*` equivalents exist — **but vDSP is subordinate to the zero-delta proof.** Vectorizing a *reduction* (sum/mean/dotprod, e.g. `reduce(0,+)` → `vDSP_meanvD`) reorders summation, is not bit-preserving, and forces a benchmark re-baseline; spend that only where the perf win is real (dominant arithmetic), not on tiny off-hot-path reductions like `PhaseIntegrator.lsSlope`'s means (`k ≤ 140`). Element-wise non-fused ops (`vsadd`/`vsub`) are bit-preserving; FMA ops (`vsma`) are not. See `docs/solutions/best-practices/vdsp-subordinate-to-zero-delta-reductions-reorder-2026-06-18.md`.
- `AnalysisConfig` is the single source of truth for window sizes, hop sizes, and thresholds. Don't hardcode these elsewhere.
- Octave safety is non-negotiable. The current 0.00% octave-error rate is the benchmark gate; do not regress it.
