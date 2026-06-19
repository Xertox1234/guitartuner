# Bass DetectionPolicy Tuning — Design

**Date:** 2026-06-18
**Status:** Design (approved) → ready for implementation plan
**Source todos:** `docs/todos/P1-bass-detection-policy-tuning.md`, `docs/todos/P1-bass-settle-stability-harness.md`
**Prior art:** 2026-06-17 instrument-profiles design (§2 root causes, §11 the lever) — Slice 1 landed the `DetectionPolicy`/`InstrumentProfile` threading inert.

## Goal

Make bass **settle** on a sustained note — eliminate the jitter, lock-flicker, and
note-name flips on E1 (41.2 Hz), A1 (55 Hz), and the 5-string low B0 (≈31 Hz) — by tuning
the currently-inert `.bass` `DetectionPolicy`. The fix must be:

- **verified** against bass-specific lock-stability metrics, not eyeballed;
- **regression-guarded** by a CI gate keyed to bass stability;
- **guitar-neutral** — guitar/`fullRange` behavior stays byte-identical (the Slice 1 zero-delta proof must still hold).

## Root causes (from the instrument-profiles design §2)

1. **Guitar-centric bands.** The 8192-sample `ultralow` window only engages below 40 Hz, so
   bass E1 (41.2 Hz) and A1 (55 Hz) fall into the `low` band's 4096 window — sized for guitar's
   82 Hz low E (~7 periods); E1 gets only ~3.5.
2. **Fragile lock streak.** Each clarity dip below the sustain floor resets `phaseIntegrator`
   (`PitchPipeline.process`), so the precise lock keeps shattering and re-earning.
3. **Lock flicker.** Bass clarity oscillates around the lock floor → strobe freeze/unfreeze.
4. **`.auto` default amplifies jitter** into note-name flips; `.lock` is the robust path for low B/E.

## Core principle: order levers by blast radius

The single most important framing. Every lever is classified as **bass-isolated** (cannot affect
guitar — tune freely) or **shared code** (could regress guitar — touch only if data forces it,
behind the zero-delta guard).

| Lever | Class | Where |
|-------|-------|-------|
| `bass.bands` window/hop geometry, `floorHz` | **isolated** | `DetectionPolicy.bass` |
| `bass.acquire` cold-start window | **isolated** | `DetectionPolicy.bass` |
| per-band `sustainConfidence` / `lockConfidence` | **isolated** | `DetectionPolicy.bass` |
| `bass.searchRange` | **isolated** (already `25...420`, done) | `DetectionPolicy.bass` |
| `emitFloor` ↔ octave-rescue decoupling | **shared** (conditional) | `PitchDetector.hybrid` |
| `phaseIntegrator.reset()` grace period | **shared** (conditional) | `PitchPipeline.process` |

**Two traps to honor (verified against current code):**

- The comb-vs-Candan refine split at `PitchPipeline.swift:164` keys off the **global**
  `AnalysisConfig.midLowHz` (120 Hz), **not** the policy. Editing `bass.bands` `floorHz` moves
  *window geometry* but does **not** reroute the refine path. This is fine — every bass string is
  < 120 Hz, so all of them are already on the harmonic-comb path — but band edits must not be
  assumed to move the refine boundary.
- `phaseIntegrator.reset()` (`PitchPipeline.swift:247`) is hardcoded pipeline logic, not a policy
  value. RC2 ("fragile lock streak") has a **safe** policy-value lever (lower bass
  `sustainConfidence`) and a **shared-code** robust fix (grace period before reset). Prefer the
  safe lever; reach for the shared fix only with data.

## Method (phased)

### Phase 0 — Make the harness policy-aware + build the ruler

**Foundational correction (verified 2026-06-18).** The benchmark is **policy-agnostic today**:
`CaseRunner.run` (`Bench/Metrics.swift:71`) constructs `PitchPipeline(sampleRate:a4:method:)` with
no `policy:` argument, so every case — including the bass notes — runs under `.fullRange`. This is
exactly why Slice 1's sha256 zero-delta proof held: bass and guitar were the same code path.
**Consequence:** tuning `bass.bands` produces *zero* benchmark delta until the harness can drive
cases under `.bass`. The first item below is therefore the foundation the other phases stand on, not
optional infrastructure.

- **Thread a `policy:` parameter** through `CaseRunner.run` → `PitchPipeline(policy:)`, defaulting to
  `.fullRange` so the existing guitar pass stays byte-identical. Add a **bass-policy pass** in
  `BenchmarkSuite` that runs the bass notes (and the weak-fund family) under `.bass`, reported in a
  dedicated section the gate reads from. Do **not** change the existing clean matrix's policy — that
  is what guards zero-delta.
- **Add lock-retention % and lock-drop count** as per-case metrics on `CaseResult` (`Bench/Metrics.swift`).
  retention % = fraction of post-first-lock frames where lock still holds; lock-drop count = times
  lock is lost mid-sustain. These capture RC3 (flicker / freeze-unfreeze), which σ alone misses
  (`timeToLock` is first-lock-only). Surface them in the new bass section so existing guitar tables
  are untouched.
- **Baseline.** Sustained bass cases already exist and are long enough to score a lock window — the
  clean matrix runs B0/E1/A1/D2/G2 for 2.6 s (`coreSeconds`) and the weak-fund stress family for
  2.2 s, both past the 1.0 s `lockWindowStart`, both already emitting `lockErrors` (today pooled into
  the clean σ but *diluted* among all guitar/mid/high, so a bass regression is invisible). The
  baseline is therefore: run those cases under `.bass`, record **bass-specific** σ / retention /
  drop / timeToLock / octave-error. This is the documented "before."

No new stimulus is needed — synthetic `inharmonicString` is the established, spec-backing methodology
(the quoted accuracy spec is built on it). Real recorded bass WAVs are **hardening, not a blocker** —
they stay deferred to the settle-stability-harness todo.

### Phase 1 — Tune bass-isolated levers (safe)

Tuned one lever at a time, each change measured against the ruler before moving on:

- **(a) `bass.bands` geometry** — extend long-window coverage upward so E1/A1 get adequate periods
  instead of the guitar-sized 4096. Watch the latency / `timeToLock` trade (longer window = slower
  lock).
- **(b) `bass.acquire`** — cold-start window octave-safe for low B.
- **(c) per-band `sustainConfidence` / `lockConfidence`** — lower the bass sustain floor so the lock
  streak holds through clarity dips on weak-fundamental bass, without admitting noise. Gated on
  octave-error staying 0.00%.

### Phase 2 — Shared-code changes (conditional)

Entered **only if** Phase 1's isolated levers don't reach the success criteria, and only with data
showing why. **Plan-structure note:** because this phase is conditional, the implementation plan must
express an explicit checkpoint — *Phase 1 → measure → decision gate → (Phase 2a / 2b / skip)* — so
the shared-code work is neither skipped nor done unconditionally.

- **`emitFloor` decoupling** — *only if* noise rejection forces bass `emitFloor` above 0.5. The clean
  move is a separate `octaveRescueFloor` (default `= AnalysisConfig.emitFloor` = 0.5) used by the
  `PitchDetector.hybrid` octave-rescue, so the rescue bar decouples from the per-instrument emit
  gate. Do **not** raise the shared `emitFloor` for the rescue. Add the deferred routing test that
  flips the octave-rescue pick on an octave-ambiguous frame (`emitFloor: 0.0` → fundamental vs
  `emitFloor: 1.0` → octave) to prove routing. Preserves zero-delta + the CI-gated 0.00%
  octave-error spec.
- **Lock-streak grace period** — *only if* the `sustainConfidence` lever isn't enough: a small grace
  period before `phaseIntegrator.reset()` so a single sub-floor frame doesn't shatter a held lock.
  This is **shared pipeline logic** → guard with the guitar zero-delta benchmark and a unit test
  pinning guitar behavior.

### Phase 3 — App-layer: flip bass to `.lock` + fix the `setInstrument` gap

- Set `InstrumentProfile.builtIn(.bass).defaultMode = .lock`.
- Fix `LiveTunerModel.setInstrument` so flipping to `.lock` actually arms `activeIdx` to the lowest
  string **after** the new tuning is in place — today it assigns `mode = profile.defaultMode`
  directly (bypassing `setMode`'s `activeIdx` arming) and then calls `setTuning` → `updateTarget`,
  so with `.lock` + nil `activeIdx` the target is nil and the strobe stays chromatic. Route through
  `setMode`/`setInputKind` (or hoist their side-effects) with correct ordering: new tuning first,
  then mode. Add a test: switching to bass ⇒ `targetNote == lowest bass string`.

### Phase 4 — Lock in the gate + re-baseline

- Add a **CI gate on bass/weak-fund lock σ** (extend the `lockSigma` pooling in `BenchmarkSuite.swift`
  or add a sibling gate in `Benchmark/main.swift`), with the threshold set **empirically from the
  tuned result, with margin** — never guessed, so it cannot red-light CI the moment it lands.
- Re-baseline `docs/benchmarks/accuracy.md` bass rows; confirm guitar rows unchanged. Full
  `swift test` + accuracy benchmark green.

## Files

- **DSP (isolated):** `Packages/TunerEngine/Sources/TunerEngine/DSP/DetectionPolicy.swift`
- **DSP (shared, conditional):** `…/DSP/PitchDetector.swift` (`octaveRescueFloor`),
  `…/Pipeline/PitchPipeline.swift` (grace-period reset)
- **Bench:** `…/Bench/Metrics.swift` (`policy:` param on `CaseRunner.run` + retention/drop on
  `CaseResult`), `…/Bench/BenchmarkSuite.swift` (bass-policy pass + bass σ pool),
  `…/Sources/Benchmark/main.swift` (bass σ gate)
- **App:** `App/Engine/InstrumentProfile.swift` (bass `defaultMode`),
  `App/Engine/LiveTunerModel.swift` (`setInstrument`)
- **Tests:** `PitchDetectorTests` (octave-rescue routing), `PipelineTests` (grace period / guitar
  pin), a `LiveTunerModel` test (bass ⇒ targetNote)
- **Docs:** `docs/benchmarks/accuracy.md` (re-baseline bass rows)

## Explicitly NOT doing (YAGNI)

- No real bass WAV recordings — synthetic `inharmonicString` is the established methodology; real
  WAVs stay deferred to `P1-bass-settle-stability-harness.md` as hardening.
- No raising the **shared** `emitFloor` value; if decoupling is needed, use `octaveRescueFloor`.
- No guitar / `fullRange` geometry change — the bass policy is isolated by construction.
- No pre-committed numeric values — windows, floors, and the gate threshold are tuned empirically
  against the ruler.

## Success criteria

- Bass lock σ materially reduced vs baseline — target well under the 0.30 gate, approaching guitar's
  lock σ.
- Lock-retention high / lock-drop ≈ 0 on sustained bass.
- **Octave-error rate stays 0.00%** (CI-gated, 207 cases incl. 5-string low B).
- **Guitar unchanged** — the guitar/`fullRange` `PitchReading` stream is identical and the existing
  guitar accuracy/σ values do not move (the Slice 1 zero-delta proof still holds). Adding bass report
  columns/sections is fine; guitar *numbers* must not change.
- `timeToLock` regression bounded and documented (a longer window on the lowest strings is physics,
  not a bug).
- CI gate added with an empirically-grounded threshold; `swift test` + accuracy benchmark green.

## Decision gate (2026-06-18)

**Phase 1 result (measured, post-Task-6, `.bass` policy):**

| Metric | Baseline (inert) | Post-Phase-1 | Target |
|--------|------------------|--------------|--------|
| bass-weak-fund lock σ | 0.17 ¢ | **0.13 ¢** | < 0.30 ✅ |
| bass-clean lock σ | 0.02 ¢ | 0.02 ¢ | < 0.30 ✅ |
| bass-weak-fund retention | 98.31 % | 98.29 % | ≥ 0.85 ✅ |
| lock drops | 0 | 0 | 0 ✅ |
| octave-error rate | 0.00 % | 0.00 % | 0.00 % ✅ |
| guitar (`.fullRange`) | — | byte-identical to main | unchanged ✅ |

**Finding (shapes the decision):** the synthetic `inharmonicString` family **already settles** under the
inert policy (98 %+ retention, 0 drops). The bass "won't settle / shatter" pathology is a *real-DI*
phenomenon the synthetic family does not reproduce. So Phase 1's value on synthetic stimulus is the
measurable **weak-fund lock σ win (0.17 → 0.13 ¢, ~24 %)** from the longer window (more periods); the
confidence-floor relaxation (Task 6) is a **defensive real-DI lever** with no synthetic benchmark
coverage (there is no bass-noise case), carrying a small, flagged real-DI permissiveness risk
(50/60 Hz mains hum). The retention/drop metrics are now **regression guards**, not fix-demonstrators.

**Decision: SKIP Phase 2 (Tasks 8 and 9).** The bass-isolated levers (band geometry + confidence
floors) met every success criterion. There is no lock-shatter to fix on the measurable stimulus and
no octave/noise regression to counter, so neither the `octaveRescueFloor` decoupling (Task 8) nor the
phase-integrator grace period (Task 9) is warranted — both would be shared-code changes taken without
data justifying them. The `emitFloor` octave-rescue coupling is therefore left intact (bass `emitFloor`
stays 0.5), and `phaseIntegrator.reset()` is unchanged.

**Note for re-baseline (Task 12):** the committed `docs/benchmarks/accuracy.md` is **stale vs main's
current engine** — the clean-matrix bass(<82 Hz) bucket reads 0.14 ¢ / σ 0.29 / max 3.79 there but
0.13 ¢ / σ 0.20 / max 1.72 today, while mid/high are byte-identical. Since this branch changes no
shared DSP path, that improvement is main's (a prior commit not followed by a doc regen), not this
branch's. Task 12's regenerated diff will surface it; do not misread it as a guitar change here.
