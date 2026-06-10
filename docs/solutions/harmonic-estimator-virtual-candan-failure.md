# Why 4× virtual Candan fine-step fails for dense bass harmonics

**Context:** Plan 06 P2 — HarmonicEstimator, June 2026.

## The problem we tried to solve

At B0 (30.87 Hz, N=4096, fs=48 kHz), the inter-partial gap is only 2.635 original DFT bins. The integer-bin Candan triplet for n=2 (bin 5.27) places its k−1 sample only 1.37 bins from the n=1 partial (bin 2.63). `|sinc(1.37)| ≈ 0.21` — 21% contamination that biases n=2's frequency estimate by +27¢.

The intuitive fix: evaluate DTFT at quarter-bin (4× virtual) intervals. This expands the effective separation to ~10.5 virtual bins (`|sinc(2.37)| ≈ 0.12`), which should reduce contamination.

## Why it didn't work for all partials

The contamination is **asymmetric** across the triplet for most B0 partials.

Example: for B0 n=4 (true bin 10.56), the n=5 partial at bin 13.22 is only 1.22 original bins from the triplet's high-side virtual bin. `|sinc(1.22)| ≈ 0.17` — this 17% inflation on the high side makes the Candan formula return a correction that is too small (underestimates the offset), and the direction of the bias varies between partials.

With integer-bin spacing these asymmetries average differently. With 4× virtual spacing, we happened to get better results for n=2 (contamination became more symmetric) but worse for n=3, n=4, n=5.

## What the diagnostic showed

```
n=2: coarse +27.15¢ → fine-old (kZP+δ)*df4 = -0.32¢  ← fine step HELPS
n=3: coarse  +3.64¢ → fine-old = +11.28¢             ← fine step HURTS
n=4: coarse -10.23¢ → fine-old = -14.03¢             ← fine step HURTS
n=5: coarse  +6.97¢ → fine-old = -1.00¢              ← fine step helps a bit
n=9: coarse  -0.49¢ → fine-old = +1.70¢              ← fine step HURTS a little
```

The WLS regression (weights ∝ n²·SNR) happened to produce <2¢ total error for B0 with the old formula because the positive and negative per-partial errors partially cancelled. But the formula was fundamentally not reliable.

## The formula confusion (don't re-derive this)

For 4× virtual Candan, the correct frequency formula is:

```swift
// WRONG: treats delta as virtual-bin offset (1/4 original bin)
let refined = (Double(kZP) + delta) * df4

// ALSO WRONG for B0 (4× overcorrects contaminated partials):
let refined = Double(kZP) * df4 + delta * binSpacing
```

For N=4096, `candan(..., n: N)` and `candan(..., n: N*4)` return the same value (the nonlinear correction is negligible). The theoretical Re(q) for quarter-bin-spaced samples ≈ 3.89× the original-bin offset — so multiplying by `binSpacing` (= 4 × df4) is theoretically correct. But that 4× amplification also amplifies contamination errors, which breaks B0 while fixing E2 (whose partials are well-separated and errors cancel).

Neither formula works for both. Don't try to resolve this by finding a scale factor between df4 and binSpacing.

## The actual solution

**Coarse-only with minBin=6.** No fine step at all.

- Integer-bin Candan via `refineFundamental` for each partial
- `minBin = 6.0` (not 4.0) to exclude B0 n=1 (bin 2.6) and n=2 (bin 5.3)
- The OLS regression over n=3…12 (weights ∝ n²·SNR) averages the remaining per-partial errors
- Outlier rejection (3·σ_rms gate) handles n=11 and other noise hits

### Why minBin=6 specifically

| Note | n | bin | included? |
|------|---|-----|-----------|
| B0 n=1 | 1 | 2.63 | ✗ DC image |
| B0 n=2 | 2 | 5.27 | ✗ proximity to n=1 |
| B0 n=3 | 3 | 7.90 | ✓ |
| E2 n=1 | 1 | 7.03 | ✓ (just above 6) |

Raising from 4 to 6 drops exactly the two contaminated low B0 partials while keeping E2's fundamental.

### Results after the fix

| Metric | Before P2 | After P2 |
|--------|-----------|----------|
| B0 abs error | 11.89¢ | 1.49¢ |
| Bass (<82 Hz) abs | 2.98¢ | 0.59¢ |
| Clean mean abs | 0.77¢ | 0.23¢ |

## Key principle

For a multi-partial WLS estimator, **regression averaging over many weighted partials is more robust than per-partial sub-bin precision when the signal is contaminated.** A "coarser" per-partial estimate that doesn't amplify contamination lets the regression do its job. This is the Fisher-weighting benefit: high-n partials (with weight n²) dominate and they have well-separated neighbors.

Fine-step refinement only helps when the per-partial signal is clean (well-separated partials, high SNR, low n). For bass strings at 30–82 Hz with N=4096, it doesn't pay.
