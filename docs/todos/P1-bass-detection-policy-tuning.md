---
priority: P1
status: open
domain: dsp, pipeline, swiftui
source: 2026-06-17 instrument-profiles design §11
depends_on: P1-bass-settle-stability-harness (verify the fix); instrument-profiles Slice 1 (landed)
---

# Tune the `.bass` DetectionPolicy — pull the lever the profile refactor built

**Severity:** High
**Source:** 2026-06-17 instrument-profiles design (`docs/superpowers/specs/2026-06-17-instrument-profiles-design.md` §11)
**Domain:** dsp, pipeline, swiftui
**Depends on:** Slice 1 (InstrumentProfile + DetectionPolicy threading) landed and inert.

## Problem

The instrument-profiles refactor (Slice 1) ships the `.bass` DetectionPolicy *constants* set to
today's exact guitar values, so the policy itself is inert (the only exception is the
policy-agnostic `nextBand` mid→sub-40 transition — see FU-1 in the Fix section). The real bass
symptom — "won't settle / jumps around on a sustained note" — is still unfixed. Root causes
(cited in the design §2):

1. **Guitar-centric bands.** The 8192-sample `ultralow` window only engages below 40 Hz, so
   bass E1 (41.2 Hz) and A1 (55 Hz) fall into the `low` band's 4096 window — sized for guitar's
   82 Hz low E (~7 periods); E1 gets only ~3.5. (`PitchPipeline.nextBand` — renamed from
   `nextConfig` in Slice 1; band selection now flows through `DetectionPolicy.band(forFrequency:)`;
   `AnalysisConfig`)
2. **Fragile lock streak.** Each clarity dip below the sustain floor resets `phaseIntegrator`,
   so the precise lock keeps shattering and re-earning (~0.43 s).
   (`PitchPipeline.process` — `phaseIntegrator.reset()` on the non-lock-integrated frame path)
3. **Lock flicker.** Bass clarity oscillates around the lock floor → strobe freeze/unfreeze.
4. **`.auto` default amplifies jitter** into note-name flips; `.lock` is "the robust path for
   low B/E" per `LiveTunerModel`.

## Fix

- Tune `DetectionPolicy.bass.bands`: extend the long window upward so E1/A1 (and the rest of
  the bottom strings) get adequate periods, instead of the guitar-sized 4096. Watch the
  latency trade (longer window = slower lock).
  - **Slice 1 transition artifact to account for (final-review FU-1).** The `nextConfig`→`nextBand`
    refactor introduced one behavioral change on the `current == mid` path: when smoothed f0 drops
    below 40 Hz, `nextBand` now returns `ultralow` (8192) where the old `nextConfig` returned `low`
    (4096) unconditionally for any f0 < 110. This is **unreachable on guitar** (60 Hz search floor),
    **unexercised by the benchmark** (steady tones never sweep mid→sub-40 — why the Slice 1 sha256
    zero-delta proof legitimately held), and on **bass** it is currently dormant and arguably *more*
    correct (reaches the long window one frame sooner). Because this slice rewrites exactly this
    transition logic, decide deliberately whether to keep it; if you change band geometry, re-confirm
    the guitar/benchmark zero-delta still holds and consider pinning the `nextBand(from: mid, f0 < 40)`
    case with a unit test. (`PitchPipeline.nextBand`.) See also the deferred identity-match hardening
    in `nextband-identity-not-label-match.md` (still uses `firstIndex(where: label ==)`).
- Tune `.bass` per-band `sustainConfidence` / `lockConfidence` **and `emitFloor`** so the
  streak and display lock hold on weak-fundamental bass without admitting noise. (Both the
  per-band sustain floor *and* the single `emitFloor` scalar gate the lock streak — bass
  clarity dips through the 0.5–0.6 band, so both matter; see design §2 RC2, §5.)
- **Decouple decision — `emitFloor` octave-rescue coupling (raised in Slice 1 Task 2 review).**
  `emitFloor` is dual-used: the pipeline emit gate *and* the octave-rescue trust bar in
  `PitchDetector.hybrid` (`lower.clarity > emitFloor ? lower : higher`, flagged with a NOTE
  comment at that line). Raising bass `emitFloor` for noise rejection *also* makes the rescue
  favor the higher (octave) candidate — a direct trade against the CI-gated 0.00% octave-error
  spec. **Before this slice raises bass `emitFloor` above 0.5, decide** whether the octave-rescue
  bar should use its own threshold (e.g. pin it to `AnalysisConfig.emitFloor`, or add a separate
  `octaveRescueFloor`) instead of the per-instrument value. This is the slice that first passes a
  non-default floor, so it is where the decision has teeth and the benchmark re-baseline catches
  any regression.
- **Add the `emitFloor` routing test deferred from Slice 1 Task 2.** The Slice-1 contract test
  (`detectAcceptsEmitFloorAndDefaultsToLegacy` in `PitchDetectorTests`) only proves the parameter
  defaults to legacy — it cannot prove the value is *routed* into the octave-rescue pick (both
  calls use 0.5). When a non-default floor is first exercised here, add a test that flips the
  octave-rescue pick on an octave-ambiguous frame (e.g. `emitFloor: 0.0` → fundamental vs
  `emitFloor: 1.0` → octave) to prove routing.
- Set bass `InstrumentProfile.defaultMode = .lock`.
  - **Side-effect gap (raised in Slice 1 Task 9 code-quality review).** `LiveTunerModel.setInstrument`
    assigns `mode = profile.defaultMode` and `inputKind = profile.defaultInput` **directly**, bypassing
    the `setMode(_:)` / `setInputKind(_:)` setters. That is inert in Slice 1 (both built-in profiles
    default to `.auto`/`.di`), but the moment bass defaults to `.lock` it skips `setMode`'s arming of
    `activeIdx` to the lowest string — so `updateTarget()` yields `targetNote == nil` and the strobe
    stays chromatic despite nominal lock mode. Likewise, a future `.mic`-defaulting profile would skip
    `setInputKind`'s `setInputPreference` push to the engine and the "Restart to apply…" status, leaving
    the engine on the wrong input until the next `start()`. **When flipping bass to `.lock` here**, route
    `setInstrument` through `setMode(profile.defaultMode)` / `setInputKind(profile.defaultInput)` (or hoist
    those side-effects — arm `activeIdx`, push `setInputPreference` — into `setInstrument`). Files:
    `App/Engine/LiveTunerModel.swift` (`setInstrument`, `setMode`, `setInputKind`).
- Widen `.bass.searchRange` down to ~25 Hz (5-string Drop A's A0 ≈ 27.5 Hz needs margin below
  the current 27 floor).
- **Verify with the settle-stability harness** (`bass-settle-stability-harness.md`) and
  re-baseline the accuracy benchmark; confirm guitar remains unchanged.

## Files

- `Packages/TunerEngine/Sources/TunerEngine/DSP/DetectionPolicy.swift` (new, from Slice 1)
- `App/Engine/InstrumentProfile.swift` (new, from Slice 1) — bass `defaultMode`
- `docs/benchmarks/accuracy.md` — re-baseline bass rows
