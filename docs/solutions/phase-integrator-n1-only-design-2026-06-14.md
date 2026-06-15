---
title: "PhaseIntegrator must use maxPartials=1, B=0 for pipeline robustness"
track: knowledge
category: design-patterns
tags: [dsp, pipeline]
module: TunerEngine
applies_to:
  - "Packages/TunerEngine/Sources/TunerEngine/DSP/PhaseIntegrator.swift"
  - "Packages/TunerEngine/Sources/TunerEngine/Pipeline/PitchPipeline.swift"
created: 2026-06-14
---

## When this applies

When calling `phaseIntegrator.feed()` from `PitchPipeline.analyze()` — choosing `maxPartials` and `inharmonicityB`.

## The pattern

Always call with `inharmonicityB: 0, maxPartials: 1`. Do not pass `harmonicB` from `HarmonicEstimator`. Do not increase `maxPartials` based on signal quality or band.

## Why

Multi-partial Fisher fusion requires accurate `fRef_n = n·f0·√(1+B·n²)` for every n. Two failure modes make this unsafe in the pipeline:

**Inharmonicity bias (n≥2 with wrong B):** If B is incorrect, `fRef_n` shifts off the real partial. The single-bin DFT at the wrong frequency accumulates systematic phase error proportional to the frequency mismatch × time, compounding across hops. Fisher weighting (w∝n²) amplifies the error for high n. For B=3×10⁻⁴, n=4: effective bias ≈ B·n² = 4.8×10⁻³, scaling fRef_4 off by 2.9¢.

**Bogus B from HarmonicEstimator on B0 pure tones:** For very low bass pure tones (B0 ~31 Hz, N=4096), `HarmonicEstimator` with `minBin=6` skips the true fundamental and n=2. The included "partials" at n=3,5,6 are Hann sidelobes. The bogus B is negative for noiseless pure tones (discarded by the `B > 0` guard in `partialFreq`), but the bogus f0 (~+11¢) propagates into the integrator's `refF0` reference.

**For n=1, inharmonicity is harmless:** `fRef_1 = f0·√(1+B) ≈ f0·(1+B/2)`. At B=3×10⁻⁴: shift ≈ 0.26¢ — the same systematic floor P1 and P2 already accept. No B estimate is needed, no failure mode exists.

**Self-correction property:** Even when `refF0` is briefly biased (from HarmonicEstimator's bogus f0 during the pre-convergence window), the LS slope recovers it: `f0_true = refF0 + slope/(2π)`. The integrator converges to the correct f0 as long as the bias stays within ±50¢ (the reset threshold). This property holds only because we're evaluating the real fundamental bin — a mistuned `fRef_1` at n=1 accumulates a steady drift that the LS fit reads back out exactly.

## Measured impact (P1+P2+P3 baseline, 2026-06-14)

- n=1, B=0: lock σ ≈ 0.12¢ at bass hop rate (N=4096/hop=1024), CI gate ≤ 0.30¢
- Theoretical multi-partial upper bound: sub-0.05¢ σ with 10 partials (per `PhaseIntegrator.swift` header)

The 0.12¢ performance meets the 0.50¢ jitter spec and earns the CI gates. The CRLB gain from multi-partial fusion would be marginal for the current accuracy spec.

## Future improvement path

If the lock σ gate is tightened below 0.05¢: add per-band `maxPartials` (n=1 for bass <120 Hz; n=3–5 for mid/high where partials are well-separated and P1 spectral refine gives reliable B). Do NOT trust `harmonicB` for n≥2 in the bass band unless you first verify: (a) B is positive, (b) 0 < B < 5×10⁻³ (physically plausible range), (c) the HarmonicEstimator minPartials requirement was met without sidelobe-only partials.

## Related files

- `Packages/TunerEngine/Sources/TunerEngine/DSP/PhaseIntegrator.swift`
- `Packages/TunerEngine/Sources/TunerEngine/Pipeline/PitchPipeline.swift`
- `Packages/TunerEngine/Sources/TunerEngine/DSP/HarmonicEstimator.swift`
- `docs/solutions/harmonic-estimator-virtual-candan-failure.md` (B0 sidelobe contamination mechanism, 2026-06-14 section)
