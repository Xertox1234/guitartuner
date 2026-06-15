# No octave-safety test in swift test covering 5-string low-B under stress signals

**Severity:** Medium  
**Audit:** 2026-06-15-full  
**Domain:** testing

## Problem

Octave-safety tests in the benchmark cover B0/E1/A1/D2/G2 on clean tones only. Stress families (weak-fund, missing-fund, vibrato) are only in the full `Benchmark --ci` run. The fast `swift test` suite has no low-B stress case. Regressions in the low-frequency path under stress are not caught by the quick test cycle.

## Fix

- Add a parameterized test to `swift test` covering the five low-string notes under at least one harmonic/missing-fundamental signal
- Use the `Stimulus` utilities to generate stress families
- Verify octave-error rate remains at 0.00% under stress

## Files

- `Packages/TunerEngine/Tests/TunerEngineTests/` (add new test file or extend existing)
