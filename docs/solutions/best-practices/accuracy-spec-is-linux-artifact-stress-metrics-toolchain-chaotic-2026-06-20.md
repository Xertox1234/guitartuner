---
title: "The published accuracy spec is the Linux CI artifact; stress-family steady-window metrics (esp. vibrato max) are toolchain-chaotic, not regressions — gate octave + lock σ, never stress max"
track: knowledge
category: best-practices
tags: [dsp, testing, pipeline]
module: TunerEngine
applies_to:
  - "docs/benchmarks/accuracy.md"
  - "Packages/TunerEngine/Sources/Benchmark/main.swift"
  - "Packages/TunerEngine/Sources/TunerEngine/Bench/BenchmarkSuite.swift"
  - ".github/workflows/ci.yml"
created: 2026-06-20
---

## When this applies

- You see a stress-family number in `docs/benchmarks/accuracy.md` that looks like a
  regression (e.g. **vibrato max 12.51 → 27.03 ¢**, σ 0.98 → 3.75) and want to bisect the
  commit that "caused" it.
- You are about to **re-baseline** `accuracy.md`, or to add a CI gate on a stress metric.
- You are reconciling why the committed `accuracy.md` disagrees with a fresh local run.

## The pattern

1. **The committed `accuracy.md` is the *Linux* CI artifact, not a local/macOS regen.**
   The `--ci` benchmark gate runs in the `engine` job on **`ubuntu-latest` (swift:6.0
   container)**; the `app` job (`macos-15`) only builds the app. CI uploads the
   `accuracy-report` artifact and echoes the report between `===ACCURACY-MD-BEGIN/END===`
   — *"the published spec is pulled from this log."* Re-baseline by pulling that artifact
   (`gh run download <run-id> -n accuracy-report`), **not** by committing a local macOS
   `--out` run — local vDSP vs the Linux path can differ in the 3rd–4th decimal of the
   CRLB / noise rows (see [[vdsp-subordinate-to-zero-delta-reductions-reorder-2026-06-18]]).
   (The generated header that read "CI (macOS) regenerates this" was a `BenchmarkSuite.markdown()`
   string literal and was **wrong** — the engine spec is regenerated on **Linux**; corrected to
   name the Linux `engine` job.)

2. **`accuracy.csv` is gitignored; only `accuracy.md` is committed — so the two can
   silently desync.** That is exactly how this doc went stale: PR #47 *hand-appended* the
   new "Bass policy" section to `accuracy.md` but left its clean/stress rows at the #32
   numbers, while the (gitignored, regenerated-each-run) `.csv` already carried the current
   values. Result: the repo's `.md` said vibrato max 12.51 while the `.csv` said 27.03.
   **Never hand-edit the generated `.md`** — append-only edits are what stale it. If you
   need durable prose, put it in the generator or a doc like this one.

3. **Stress-family *steady-window* metrics are toolchain-chaotic. The gated invariants are
   robust.** Same code, rebuilt under a later CI image, moved vibrato steady max
   12.51→27.03, σ 0.98→3.75, and weak-fund `n` 348→303 — with **zero code change** (proven:
   #32 rebuilt *today* on macOS reproduces 27.03 while the #32-era Linux doc recorded 12.51 —
   same code, different toolchain; and current main is identical at 27.03 on macOS and the
   Linux CI artifact). Meanwhile clean abs (0.10¢), octave-error rate (0.00%), and
   **held lock σ** stayed put. So: a shifted stress number is **not** evidence of a code
   regression — don't bisect for a culprit that isn't there.

4. **`vibrato max ¢` is a single pre-lock *acquisition transient*, not a steady-state
   tracking error — and not sustained following.** The stress score pools the **steady
   window (after 300 ms)** against the vibrato **centre** while `Synth.vibrato` swings
   ±30 ¢ at 5.5 Hz. The per-note shape is heavy-tailed — E4 meanAbs **1.01 ¢**, σ **4.12 ¢**,
   max **27 ¢** — which is *incompatible* with smooth following (sustained following of
   amplitude A would give meanAbs ≈ 0.64·A ≈ 17 ¢, not 1 ¢). A per-reading trace shows the
   max is **one contiguous monotonic burst at t ≈ 0.30–0.37 s** — one half-swing of the FM
   caught while the PhaseIntegrator is still acquiring (`isLockIntegrated == false`). At
   t ≈ 0.37 s the integrator locks and the error never again exceeds ~2 ¢, decaying to
   sub-0.3 ¢ (bucketed RMS: 0.30–0.60 s ≈ 10.5 ¢, 0.60–1.0 s ≈ 0.22 ¢, 1.0–2.2 s ≈ 0.15 ¢).
   So the number is a **one-shot settling excursion**, not a tracker biasing every reading.
   The honest quality signal is the **held lock window (after 1 s)**: vibrato **lock σ held
   at 0.04 ¢** across the very toolchain shift that moved the max 12.51→27.03 (per-note
   0.044 / 0.058 / 0.000); octave-error stayed 0; once locked it pins to centre. That the
   max is a *threshold-crossing acquisition transient* is precisely why it flips on
   hop-timing / 3rd-decimal float differences across toolchains — and why it scales with f0
   (E2 12.5 / G3 21.5 / E4 27.0), i.e. with swing amplitude at the acquisition hop, not a
   fixed error.

## What to do (and not do)

- **Re-baseline** = pull the Linux `accuracy-report` artifact for the target commit and
  commit `accuracy.md` verbatim. Don't commit a local macOS regen; don't hand-edit rows.
- **Don't add a `git diff --exit-code` "doc is current" CI check.** The doc is
  toolchain-sensitive, so a diff against fresh CI output would flake red on every image
  bump — the same mechanism that produced the stale doc. Use a process note instead:
  *source of truth is the Linux artifact; regenerate after a toolchain/image bump.*
- **Don't gate stress max/abs.** They are chaotic + toolchain-sensitive; a threshold would
  flake. But be honest about the residual: the **pre-lock excursion is gated by nothing** —
  the octave gate only trips `>600 ¢` (`Metrics.swift`), time-to-lock records the *first*
  conf≥0.9 touch (before the burst), and lock-σ is measured only after 1.0 s. So sub-octave
  pre-lock / re-acquisition excursions are an **accepted, ungated residual**; the gated
  invariants are octave-safety (`stressOctaveErrors == 0`, `main.swift`) and post-1 s lock-σ,
  *not* the acquisition window. A genuine future regression confined to that window
  (e.g. 27→200 ¢, still `<600 ¢`, first-touch lock-ms unchanged) would pass every gate —
  only a dedicated pre-lock-excursion or sustained-lock-time metric would catch it. If you
  want a stress *quality* gate, lock-σ is the right candidate (it held 0.04 ¢ across the
  shift), but it's a new, TDD'd gate, not a doc refresh — and don't tighten existing
  thresholds (worst-abs, etc.) in a re-baseline.
- **Don't "fix" 27.03 in the engine.** No code caused it, and it's an acquisition transient,
  not steady drift; adding smoothing to chase a non-gated benchmark number would slow real
  lock acquisition (and bend/vibrato following) for nothing.

## Why (the incident)

Backlog `P2-accuracy-md-stale-vibrato-regression` asked to "bisect which main commit moved
vibrato max 12.51→27.03." There is no such commit. The bisect found the number already at
27.03 at #43's parent and #32 (rebuilt today on macOS) and on current main (macOS and the
Linux CI artifact, identical to 5 figures) — while the #32-era committed doc (Linux,
2026-06-15) recorded 12.51. Same code →
different number across **time** (CI image), same number across **OS** ⇒ an
environment/toolchain shift outside the repo, surfaced (not caused) by the doc being stale
and the `.md`/`.csv` desync from #47. The fix is a clean re-baseline from the Linux
artifact + this note; the engine is correct and unchanged. `accuracy.md` is now re-baselined
to 27.03 to match current CI and the backlog item resolved — see
`docs/todos/archive/P2-accuracy-md-stale-vibrato-regression.md`. (Don't re-open the bisect.)

Related: [[vdsp-subordinate-to-zero-delta-reductions-reorder-2026-06-18]] (reductions
reorder → different bits; `accuracy.csv` is gitignored so the proof is a same-platform
regenerate-and-diff).
