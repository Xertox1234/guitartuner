# Bass Policy Baseline — Inert `.bass` Policy

**Date:** 2026-06-18
**Branch:** feat/bass-detection-policy-tuning

**Command:**
```
swift run -c release --package-path Packages/TunerEngine Benchmark --method mpm 2>/dev/null
```

## Bass policy (bass notes under `.bass`)

Bass strings driven through the **`.bass`** DetectionPolicy (the rest of the report uses `.fullRange`). Lock retention = fraction of held-window frames holding the phase-integrator lock; drops = mid-sustain lock losses. This is the bass-settling signal the Phase 4 gate reads.

| Family | n | abs ¢ | lock σ ¢ | lock retention | lock drops |
|---|---|---|---|---|---|
| bass-clean | 443 | 0.28 | 0.02 | 100.00% | 0 |
| bass-weak-fund | 443 | 0.32 | 0.17 | 98.31% | 0 |

## Summary numbers

| Metric | Value |
|---|---|
| `bassLockSigma` (bass-clean) | 0.02 ¢ |
| `bassLockSigma` (bass-weak-fund) | 0.17 ¢ |
| `bassLockRetention` (bass-clean) | 100.00% |
| `bassLockRetention` (bass-weak-fund) | 98.31% |
| `bassLockDrops` (bass-clean) | 0 |
| `bassLockDrops` (bass-weak-fund) | 0 |

## Interpretation

Synthetic stimulus already settles well under the inert `.bass` policy: both families show high lock retention (≥ 98%) and zero mid-sustain lock drops, meaning the "shatter" pathology visible on real DI recordings does not manifest in synthesized tones. Phase 1 tasks can therefore demonstrate tuning improvements on synthetic stimulus for the `bass-weak-fund` σ (currently 0.17 ¢, meaningful headroom vs. the 0.02 ¢ clean floor), but tests targeting lock retention and drop elimination must be treated as defensive for real DI — synthetic tones will show 0 drops regardless of policy parameters.
