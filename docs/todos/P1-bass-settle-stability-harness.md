---
priority: P1
status: open
domain: testing, dsp
source: 2026-06-17 instrument-profiles design §11–§12
---

# Build a settle-stability harness — the benchmark can't see "won't settle"

**Severity:** High
**Source:** 2026-06-17 instrument-profiles design (`docs/superpowers/specs/2026-06-17-instrument-profiles-design.md` §11–§12)
**Domain:** testing, dsp
**Related:** medium-M17 (StimulusTests → full-pipeline driving) — resolved in the 2026-06-18 sweep.

## Problem

The reported bass symptom is *temporal* — the reading won't settle / jumps around on a
sustained note. The accuracy benchmark measures per-estimate cents error on clean/inharmonic
synthetic tones; it is blind to settling behavior. We cannot prove the bass-policy fix
(`P1-bass-detection-policy-tuning.md`) works, or guard against regressions, without a metric that
observes stability over time on realistic stimulus.

## Fix

- Add a settle-stability metric driven through the **full `PitchPipeline`** (not `PitchDetector`
  directly — the full-pipeline driving medium-M17 also called for, now resolved):
  - **cents σ** over a steady sustained window (post-attack),
  - **lock-retention %** — fraction of frames where lock holds once first achieved,
  - **lock-drop count** — number of times lock is lost mid-sustain.
- Drive it with realistic stimulus: the real-DI/mic bass fixtures (see `Bench/Fixtures.swift`
  and the `a4d884a` real-DI fixtures) and the weak-fundamental synthetic family
  (`Bench/Stimulus.swift`), which model the weak-fundamental reality the clean benchmark omits.
- Establish baselines under `.guitar`-equivalent vs tuned `.bass` policy to quantify the win.
- Decide whether the metric becomes a CI gate (like the accuracy benchmark) or a report-only
  diagnostic initially.

## Files

- `Packages/TunerEngine/Sources/TunerEngine/Bench/` (new metric + probe)
- `Packages/TunerEngine/Tests/TunerEngineTests/` (regression test)
- `docs/benchmarks/` (baseline report)
