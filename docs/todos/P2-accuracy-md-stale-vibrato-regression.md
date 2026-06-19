---
priority: P2
status: open
domain: dsp, testing
source: 2026-06-18 bass-detection-policy-tuning re-baseline (PR — surfaced, not caused, by that branch)
---

# Re-baseline accuracy.md on main + investigate a vibrato stress regression

## Problem

The committed `docs/benchmarks/accuracy.md` is **stale vs main's current engine** — it is dated
`2026-06-15` and predates main commits (e.g. instrument-profiles Slice 1 #43, the L7 fix #44) that
changed measured accuracy without a doc regen. Running the benchmark on a branch that changes **no
shared DSP** (the bass-detection-policy branch) against this doc reveals the drift:

- **Improvements (good, but unbaselined):** bass(<82 Hz) clean abs 0.14→0.13 ¢, clean worst-case
  3.79→1.72 ¢, B0 0.40→0.18 ¢, harmonic/inharmonic σ tighter.
- **⚠️ Regression — vibrato stress family:** abs 0.33→0.95 ¢, σ 0.98→3.75 ¢, **max 12.51→27.03 ¢**
  (octave-errors still 0, so the CI gate — which only gates `stressOctaveErrors`, not stress
  abs/σ/max — does **not** catch it). Vibrato runs under `.fullRange`, so this is a guitar/main-path
  regression, not bass-specific.

This was **surfaced by**, not **caused by**, the bass-detection-policy PR (that branch's
`accuracy.md` change was scoped to add only the new "Bass policy" section; it left the stale
clean/stress numbers untouched precisely so main's drift would not be misattributed to it).

## Fix

1. **Re-baseline on main:** regenerate `docs/benchmarks/accuracy.md` + `.csv` from main's current
   engine (`swift run -c release --package-path Packages/TunerEngine Benchmark --out docs/benchmarks`)
   and commit, so the published spec is current again. Add a CI check (or process note) so the doc
   does not drift unbaselined again.
2. **Investigate the vibrato regression:** bisect which main commit moved vibrato max 12.51→27.03 ¢
   (likely #43 Slice 1 or #44 L7 fix). Determine whether it is a real tracking regression on pitch
   modulation (matters for real vibrato/bends) or a benchmark-stimulus artifact. Decide whether to
   add a `stressWorstAbsCents` (or vibrato-specific) CI gate so stress regressions are caught, not
   just octave errors.

## Files

- `docs/benchmarks/accuracy.md`, `docs/benchmarks/accuracy.csv` (regenerate)
- `Packages/TunerEngine/Sources/Benchmark/main.swift` (`--ci` gate — consider a stress-magnitude gate)
- `Packages/TunerEngine/Sources/TunerEngine/Bench/Stimulus.swift` (`Synth.vibrato`) — if the
  regression is investigated as a tracking vs stimulus question

## Verification

Accuracy-gated DSP path. Re-baseline must keep the headline + octave invariants intact
(`Benchmark --ci` exits 0). For the vibrato investigation, drive `Synth.vibrato` through the
pipeline headlessly and compare against a known-good main commit (git bisect on the benchmark
vibrato max).
