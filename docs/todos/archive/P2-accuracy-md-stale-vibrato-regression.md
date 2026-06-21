---
priority: P2
status: resolved
domain: dsp, testing
source: 2026-06-18 bass-detection-policy-tuning re-baseline (PR — surfaced, not caused, by that branch)
resolved: 2026-06-20
---

# Re-baseline accuracy.md on main + investigate a vibrato stress regression

## Resolution (2026-06-20)

**Re-baselined `accuracy.md` from the authoritative Linux CI artifact; the "vibrato
regression" is not a regression.** Both halves of the Fix are done:

1. **Re-baseline (done).** Replaced the committed `accuracy.md` with the current-main
   **Linux** `accuracy-report` artifact (`gh run download` from the #54 merge run), not a
   local macOS regen — the engine `--ci` gate runs on `ubuntu-latest` and *that* is the
   published spec. The committed doc was stale because PR #47 hand-appended the "Bass
   policy" section while leaving the clean/stress rows at #32's numbers; the gitignored
   `.csv` was already current, so `.md`/`.csv` had silently desynced. Now in sync, dated
   2026-06-20. (No `git diff` "doc-current" CI check added — it would flake on every
   toolchain bump; a process note replaces it. See solutions note below.)

2. **Investigation (done) — no code regression, no commit to bisect.** Rebuilding #43's
   parent and #32 *today* (macOS) and current main (macOS + the Linux CI artifact) all
   reproduce **vibrato max 27.03 ¢, σ 3.75, abs 0.95** — identical to 5 figures where
   compared cross-OS (current main) — while the #32-era committed doc (Linux, 2026-06-15)
   recorded 12.51/0.98/0.33. The clean controlled experiment: #32 rebuilt today (27.03) vs
   the #32-era doc (12.51) — same code, different toolchain. Same code → different number
   across **time** (CI image), same number across **OS** ⇒ an out-of-repo
   **toolchain/image baseline shift**, not a code change (weak-fund `n` 348→303 moved the
   same way). `vibrato max` is a single **pre-lock acquisition transient**, not a tracking
   error: a per-reading trace shows one monotonic burst at t ≈ 0.30–0.37 s (one half-swing
   of the ±30 ¢ FM caught while the PhaseIntegrator is still acquiring), after which it
   locks and error stays <2 ¢ → sub-0.3 ¢. The heavy-tailed shape (E4 meanAbs 1.01 ¢, σ
   4.12 ¢, max 27 ¢) is incompatible with sustained following (~17 ¢) — it's a one-shot
   settling excursion whose threshold-crossing peak flips on hop-timing across toolchains.
   The honest quality signal — **held lock σ — stayed 0.04 ¢** across the entire shift
   (per-note 0.044 / 0.058 / 0.000), and octave-error stayed 0. The engine is correct;
   nothing to fix.

**Gate decision:** do **not** add a `stressWorstAbsCents`/abs gate — those metrics are
chaotic + toolchain-sensitive and would flake. The vibrato invariant is already gated
(`stressOctaveErrors == 0`). If a stress *quality* gate is ever wanted, gate a **lock-σ**
metric (it held 0.04 ¢ across the shift) as a separate TDD'd change — out of scope for a
doc refresh, and existing thresholds were left untouched.

**Codified:** `docs/solutions/best-practices/accuracy-spec-is-linux-artifact-stress-metrics-toolchain-chaotic-2026-06-20.md`
(published spec = Linux artifact; stress steady-window metrics are toolchain-chaotic; gate
octave + lock σ, never stress max; never hand-edit the generated `.md`).

---

## Original report (for the trail)

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
