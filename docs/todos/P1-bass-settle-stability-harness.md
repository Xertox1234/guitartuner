---
priority: P1
status: partial
domain: testing, dsp
source: 2026-06-17 instrument-profiles design §11–§12
---

# Build a settle-stability harness — the benchmark can't see "won't settle"

**Severity:** High
**Source:** 2026-06-17 instrument-profiles design (`docs/superpowers/specs/2026-06-17-instrument-profiles-design.md` §11–§12)
**Domain:** testing, dsp
**Related:** medium-M17 (StimulusTests → full-pipeline driving) — resolved by commit `48dc5f6`
(Jun 15; not the 2026-06-18 sweep as originally credited here).
**Verified & rescoped:** 2026-06-18 against current code — roughly half the original plan already
exists, so this todo was narrowed to the genuinely-unbuilt residue. See Problem/Fix below.

## Problem

The reported bass symptom is *temporal* — the reading won't settle / jumps around on a
sustained note.

**Correction (2026-06-18):** the accuracy benchmark is **not** blind to settling, as this todo
originally claimed. `CaseRunner.run` already drives the **full `PitchPipeline`** over a time
sequence (feeds stimulus in ~10 ms blocks, `Bench/Metrics.swift:71-81`), already computes a
**held-note lock-window cents σ** for every case (`lockStats`/`lockErrors`, `Metrics.swift:101-103`),
and already **CI-gates** it (`lockSigma > 0.30` hard-fails, `Benchmark/main.swift:86`). The
full-pipeline-driving M17 it referenced is resolved (`StimulusTests.runPipeline`, commit `48dc5f6`).

The *real* gaps are narrower than "build a settle harness": (a) there is **no lock-retention /
lock-drop metric** — `timeToLock` is first-lock-only and never notices a mid-sustain drop
(`Metrics.swift:84-90`); and (b) the CI-gated `lockSigma` pools **clean tones only**
(`clean.flatMap { $0.lockErrors }`, `BenchmarkSuite.swift:173`), so bass/weak-fund lock σ is
reported in markdown but never gated. We still cannot prove the bass-policy fix
(`P1-bass-detection-policy-tuning.md`) holds *on bass* or guard the regression.

## Fix (rescoped to the unbuilt residue)

- **Add lock-retention % and lock-drop-count metrics** to `CaseRunner`/`ErrorStats`. These are the
  only fully-absent metrics today (`timeToLock` is first-lock-only). lock-retention % = fraction of
  post-first-lock frames where lock still holds; lock-drop count = times lock is lost mid-sustain.
- **Gate σ on realistic bass/weak-fund stimulus**, not just clean tones — extend the `lockSigma`
  gate (or add a sibling gate) to pool the bass/weak-fund families, so a bass policy that won't
  settle actually fails CI.
- **Establish a `.guitar`-vs-`.bass` stability baseline.** Note `guitarClampMatchesFullRangeOnGuitarNotes`
  (`PipelineTests.swift:193-209`) only asserts policy *equality on guitar notes* — it is not a
  bass-stability comparison.
- **Commit real recorded bass WAVs** into `docs/benchmarks/fixtures/` (currently only a README; the
  `Bench/Fixtures.swift` loader is ready and waiting). Correction: the `a4d884a` commit this todo
  originally cited for "real-DI fixtures" is **docs-only** (touched only
  `docs/plans/06-accuracy-engine.md`); the loader code actually came from `1105eb9`, and no audio
  has ever been committed. The weak-fundamental synthetic family
  (`Synth.inharmonicString(fundamentalLevel:)`, `Bench/Stimulus.swift:69-86`) does exist.

### Already built (do NOT re-do)

- Full-`PitchPipeline` driving over time sequences (`CaseRunner.run`) — used by the whole benchmark.
- cents-σ-over-sustained-window metric (`lockStats`) **and** a CI gate on it (`lockSigma`).
- weak-fundamental synthetic family and the real-DI WAV loader (`Bench/Fixtures.swift`).

## Files

- `Packages/TunerEngine/Sources/TunerEngine/Bench/Metrics.swift` — add lock-retention/drop to
  `CaseRunner`/`ErrorStats` (existing `lockStats`/`timeToLock` live here)
- `Packages/TunerEngine/Sources/TunerEngine/Bench/BenchmarkSuite.swift` — pool bass/weak-fund σ
- `Packages/TunerEngine/Sources/Benchmark/main.swift` — extend the `--ci` gate (`lockSigma` at :86)
- `Packages/TunerEngine/Tests/TunerEngineTests/` (regression test)
- `docs/benchmarks/fixtures/` — drop real bass WAVs (loader: `Bench/Fixtures.swift`)
- `docs/benchmarks/` (baseline report)
