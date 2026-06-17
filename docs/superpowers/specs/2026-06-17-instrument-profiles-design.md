# Instrument Profiles — Design

**Date:** 2026-06-17
**Status:** Approved for planning
**Author:** brainstorm session (LUMA)

## 1. Context & reframe

The original request was "add an instrument-profile system, starting with guitar and bass,
as the foundation for fixing bass tuning, which currently works poorly." Exploring the code
overturned two premises:

1. **A profile system already exists, substantially.** `Instrument` (`.guitar`/`.bass`),
   `Tuning`/`GuitarString`, and `Tunings` presets (7 guitar + 5 bass, incl. 4-string,
   5-string B0, and 5-string Drop A) live in `LumaDesignSystem/Model/Tuning.swift`.
   Frequencies are already derived from MIDI + A4 (`Tunings.make` → `Note.frequency`), A4 is
   configurable (430–450) and persisted, `TargetMode` (`.auto`/`.lock`) targeting exists in
   `LiveTunerModel`, and `TuningCard` is a `Codable` profile (instrument + tuning + a4 +
   palette) with cloud + local persistence.

2. **The detection layer already solves the "obvious" bass problems.** Detection is NSDF/MPM
   autocorrelation with a frequency-adaptive window up to 8192 samples and a dedicated
   `ultralow` band for B0 (~31 Hz); octave correction exists in four layers; a 28 Hz
   Butterworth high-pass preserves B0. The CI-gated benchmark reports B0 = 0.40¢, E1 = 0.33¢,
   weak-fund family 0.63¢, **0 octave errors**.

So the task is **not** new frequencies or a new octave-correction algorithm. It is: (a) make
the existing instrument concept *first-class* by introducing a unifying `InstrumentProfile`,
and (b) give that profile the small set of **detection-policy knobs** that actually drive the
real bass symptom — which the synthetic benchmark is blind to.

## 2. The real bass failure: "won't settle / jumps around"

Reported symptom (user-confirmed): on a sustained bass pluck the reading wanders / never
stabilizes. This is **not** wrong frequencies, **not** octave lock-up, **not** primarily
latency. It traces to four instrument-policy mismatches, all invisible to a synthetic
benchmark (clean sustained tones clear gates that real weak-fundamental bass hovers at the
edge of):

1. **Guitar-centric frequency bands.** The long 8192-sample (`ultralow`) window only engages
   below 40 Hz (`AnalysisConfig.lowUltraLowHz`). Bass open strings **E1 (41.2 Hz)** and
   **A1 (55 Hz)** fall into the `low` band's **4096** window, which was sized for *guitar's*
   low E (82 Hz ≈ 7 periods). E1 gets ~3.5 periods; AnalysisConfig's own comment notes 4096
   yields "~2–4¢ inter-partial leakage" at this range. Noisier per-hop estimate → jitter.
   (`PitchPipeline.nextConfig:298`, `AnalysisConfig.swift:59`)

2. **The precise lock is a fragile clarity streak.** `isLockIntegrated` (the sub-0.05¢
   phase-slope reading) needs clarity ≥ 0.6 for 3+ consecutive frames **and** ≥20 accumulated
   hops with ≤1¢ residual. Every dip below 0.6 calls `phaseIntegrator.reset()`
   (`PitchPipeline.swift:225`), so on real bass the reading repeatedly almost settles, then
   drops back to the noisier per-hop EMA and re-earns the lock (~0.43 s).

3. **The display lock flickers.** Bass lock gate is a single global `minLockConfidence = 0.75`
   (`PitchReadingStrobe.swift:14`). Real bass clarity oscillating around 0.75 makes the strobe
   freeze/unfreeze → "can't settle."

4. **Default `.auto`/chromatic mode amplifies all of it.** In `.auto` the *note name* is the
   chromatic nearest, so a wandering estimate flips E1↔F1 and swings cents ±50. The code
   itself calls `.lock` "the robust path for low B/E" (`LiveTunerModel.swift:18`), yet the
   default is `.auto`.

## 3. Goals & non-goals

**Goals**
- Introduce a first-class `InstrumentProfile` that unifies instrument + default tuning +
  detection policy + UX defaults, *respecting the package-boundary invariant*.
- Consolidate the scattered detection constants the team already flagged as debt
  (`M2` gate thresholds, `M3` lock constants, `M7` band thresholds) into one typed source.
- Restore last-used instrument/tuning across launches.
- Build the *lever* for fixing bass (the policy knobs the engine honors), without yet pulling
  it — so the refactor lands with **zero accuracy-benchmark delta**.

**Non-goals (this slice)**
- Tuning the actual `.bass` policy values, flipping bass to `.lock`, or building the
  settle-stability harness. These are the bass *fix* and are deferred (see §11).
- Any change to guitar *detection/accuracy* output (the clamp in §10 is verified zero-delta,
  not assumed), or to the `TuningCard` backend schema.
- New instruments beyond guitar/bass.

Note: persistence (§9) and the guitar clamp (§10) are intended, contained changes; the
"inert / zero-delta" guarantee (§11) is specifically about the **accuracy-benchmark / DSP
output**, not about app launch behavior.

## 4. Architecture — the 3-layer split

**Hard constraint (CLAUDE.md invariant):** `TunerEngine` imports no UI/design-system;
`LumaDesignSystem` imports no DSP/engine. A single unified type cannot hold both a `Tuning`
(LumaDesignSystem) and detection policy (consumed by TunerEngine).

**Decision: split across the three layers; the App layer composes the unified profile.**

```
TunerEngine      ──►  DetectionPolicy   (NEW pure-DSP value type)
LumaDesignSystem ──►  Instrument, Tuning, presets   (UNCHANGED, stays logic-free)
App layer        ──►  InstrumentProfile (NEW; composes Tuning + DetectionPolicy + UX)
```

The App layer is the only place allowed to know both packages — exactly where `LiveTunerModel`
and `PitchReadingStrobe` already bridge them. `InstrumentProfile` lives next to them.

(Rejected alternative: move `Instrument`/`Tuning` into a shared low-level package so one type
holds everything. Bigger blast radius — `TuningCard`, `LiveTunerModel`, the package graph —
for cosmetic gain. The 3-layer version is already first-class; it just respects the boundary.)

## 5. Data model

### `DetectionPolicy` — in `TunerEngine` (pure DSP, `Sendable`/`Equatable`/`Codable`)

Only knobs that genuinely vary by instrument or are needed for the bass fix. Everything else
stays an engine constant.

```swift
public struct DetectionPolicy: Sendable, Equatable {
    public var searchRange: ClosedRange<Double>   // bass: ~25…~420 ; guitar: ~60…1400
    public var bands: [BandSpec]                   // ordered high→low (consolidates M7)
    public var acquire: BandSpec                   // cold-start window
    public var smoothingAlpha: Double              // EMA aggressiveness
    public var smoothingMedianCount: Int           // outlier-rejection window
    public var emitFloor: Double                   // unvoiced threshold (RC2; see note below)

    public static let guitar = DetectionPolicy(/* today's exact constants */)
    public static let bass   = DetectionPolicy(/* = guitar values in Slice 1; tuned later */)
}

public struct BandSpec: Sendable, Equatable {
    public var window: Int
    public var hop: Int
    public var floorHz: Double
    public var hysteresisHz: Double
    public var sustainConfidence: Double   // gate floor for this band (consolidates M2)
    public var lockConfidence: Double      // strobe/lock-mode floor for this band (M3)
    public var label: String
}
```

Not `Codable`: nothing persists a `DetectionPolicy` (built-in profiles are code-defined;
persistence in §9 stores only instrument + tuning id). Same YAGNI logic as `InstrumentProfile`.

Three load-bearing decisions:

- **The band plan is data, not constants.** `bands` *is* the fix-lever for root cause #1.
  Guitar's plan = today's exact values (table below). The bass fix later extends the long
  window upward so E1/A1 get enough periods.
- **Confidence floors live per-band, not as one scalar.** Today's lock floor is
  *frequency-dependent* (0.75 below 120 Hz, 0.9 above) and that split helps **low guitar
  strings too**. Per-band floors preserve guitar exactly while giving bass its own floors.
- **`emitFloor` is a single policy scalar (not per-band), defaulted to 0.5 (inert).** It is the
  *other half* of root cause #2: a frame with `clarity < emitFloor` goes fully unvoiced
  (`handleUnvoiced` → `unvoicedStreak`; after 8, a full reset to `acquire`), so bass clarity
  dipping through the 0.5–0.6 band shatters the lock streak just as `sustainConfidence` does
  (deferred todo #2 needs both). It is a *single scalar*, not per-band, because it is
  **dual-used**: besides the pipeline gate, `PitchDetector`'s hybrid octave-rescue compares
  `lower.clarity > emitFloor`. Threading it into both sites with one value is simpler and safer
  than a per-band field there.

Helpers: `DetectionPolicy.lockConfidence(forFrequency:)` and `sustainConfidence(forFrequency:)`
do a **pure floor-based band lookup** (`band(forFrequency:)` — *not* the hysteretic current
band), matching today's `minLockConfidence`, which is a pure function of frequency.

### Band-transition semantics (the highest zero-delta risk — pin it exactly)

Today's `nextConfig` is **stateful**: a hand-written `switch config.label` with asymmetric
per-boundary hysteresis that depends on the band you are *currently* in. The flat `[BandSpec]`
must reproduce it bit-for-bit. Pinned semantics:

> The boundary *below* band X (between X and the next-lower band) sits at **`X.floorHz`**, with
> margin **`X.hysteresisHz`**. Transition rules, given current band X:
> - drop to the next-lower band when `f0 < X.floorHz − X.hysteresisHz`;
> - rise to the band above when `f0 ≥ (bandAbove).floorHz + (bandAbove).hysteresisHz`.
>
> `acquire` resolves its first settled band by the **pure floor lookup** (no hysteresis),
> matching today's `band(forFrequency:)`.

**Exact guitar `BandSpec` table (must reproduce `main` by inspection):**

| label    | window | hop  | floorHz | hysteresisHz | sustainConfidence | lockConfidence |
|----------|--------|------|---------|--------------|-------------------|----------------|
| high     | 1024   | 256  | 250     | 15           | 0.6               | 0.90           |
| mid      | 2048   | 512  | 120     | 10           | 0.6               | 0.90           |
| low      | 4096   | 1024 | 40      | 5            | 0.6               | 0.75           |
| ultralow | 8192   | 2048 | 0       | 0            | 0.6               | 0.75           |
| acquire  | 4096   | 1024 | —       | —            | 0.6               | —              |

Two traps this table defuses: **`sustainConfidence` is uniform 0.6 across all bands**
(today's `sustainMinConfidence`); **`lockConfidence` is the 0.75/0.9 split at the 120 Hz
mid/low boundary** (today's `minLockConfidence`). Do not let sustain follow the lock split, or
make lock uniform — either is a silent delta.

**Stays an engine constant** (universal, deliberately *not* parameterized): `nsdfPeakK` (0.9,
McLeod), `octaveGuardMinClarity` (0.95), `lockPrecisionThreshold` (1.0¢), `smoothingSnapCents`
(120, note-change), and the phase-integrator's `minHops`/`maxHops`.

### `InstrumentProfile` — in the App layer (the unifying composition)

```swift
struct InstrumentProfile: Identifiable, Sendable {
    let id: Instrument                 // .guitar / .bass — the instrument IS the id
    var displayName: String
    var defaultTuning: Tuning          // LumaDesignSystem type
    var detection: DetectionPolicy     // TunerEngine type
    var defaultMode: TargetMode        // guitar → .auto ; bass → .lock (deferred flip)
    var defaultInput: InputKind

    static func builtIn(_ i: Instrument) -> InstrumentProfile { … }   // code-defined registry
}
```

Built-in profiles are **code-defined, not Codable/persisted** — only `TuningCard` tunings
persist. (If user-editable detection profiles are ever wanted, `InstrumentProfile` can be made
Codable then; not now — YAGNI.)

## 6. Engine threading

- **`PitchPipeline`** gains `policy: DetectionPolicy` (default `.guitar`) and `setPolicy(_:)`
  that resets smoother/gate/band state.
  - `nextConfig(for:)` iterates `policy.bands` (+ `policy.acquire`) instead of the static
    `AnalysisConfig` configs/thresholds — same selection logic, data-driven.
  - `searchRange` → `policy.searchRange`.
  - `FrequencySmoother` is built from `policy.smoothingAlpha` / `smoothingMedianCount`.
  - **`SustainGate` floor becomes per-hop, band-keyed:**
    `gate.step(confidence:, floor: config.sustainConfidence)` — the floor now depends on the
    current band.
- **`TunerEngine`** actor gains `setDetectionPolicy(_:)` forwarding to `pipeline.setPolicy(_:)`,
  matching the existing `setA4`/`setTargetNote`/`setInputPreference` setters; safe while running.
- **The lock floor** replaces `PitchReadingStrobe.minLockConfidence`:
  `PitchReading.strobeInput(minLockConfidence:)` takes the floor as a parameter;
  `LiveTunerModel` computes it from `profile.detection.lockConfidence(forFrequency:)` and passes
  it. Deletes the hardcoded app-layer constant (`M3`).

## 7. `LiveTunerModel` migration

- Holds `private(set) var profile: InstrumentProfile = .builtIn(.guitar)`; `instrument`
  becomes `profile.id`.
- `setInstrument(_:)` swaps the profile, pushes `profile.detection` to the engine, applies
  `defaultMode`/`defaultInput`, and sets the default tuning (existing "keep selection valid"
  logic stays).
- `start()` pushes `profile.detection` alongside the other engine setup.
- `apply(_:)` gates lock on `profile.detection.lockConfidence(forFrequency: adjFreq)` in both
  the `.lock` and `.auto` branches.

## 8. `TuningCard` relationship — no schema change, no backend migration

`TuningCard` stays exactly as-is (it is persisted server-side). A card carries a *tuning* +
instrument + a4 + palette — **not** detection policy. The existing `loadCard` flow already
calls `setInstrument(card.instrument)` first, which now selects the `InstrumentProfile` and
pushes its `DetectionPolicy`; the card then overrides tuning/a4/palette. So **detection policy
is derived client-side from `card.instrument` at load time, never stored on the card.** A
custom Drop-C bass card automatically gets bass detection policy.

## 9. Persistence — restore last-used instrument/tuning

New (UX-additive, no DSP/accuracy impact): persist the last-used instrument and tuning id via
`@AppStorage`, and restore on launch instead of always resetting to guitar. First launch still
defaults to guitar. Does not touch the accuracy benchmark.

## 10. Guitar `searchRange` clamp

Clamp guitar's search range floor up from 27 Hz to **~60 Hz** for extra octave-safety
headroom. Constraint that fixes the naive choice: the guitar presets include **Drop C
(C2 = 65.4 Hz)**, so the floor must sit *below* C2 with margin — ~60 Hz, **not** 70 Hz (70
would stop the detector from ever finding Drop C → regression).

**Hard rule:** the clamp must verify as **zero benchmark delta** (no guitar fundamental lives
below 65.4 Hz, so clamping out 27–60 Hz removes only spurious sub-bass candidates). If any
guitar case regresses in CI, revert guitar to `27…1400`. Bass keeps a wide range (down to
~25 Hz for 5-string Drop A's A0 ≈ 27.5 Hz), tuned in the deferred work.

## 11. Slice plan & the zero-delta safety property

**Slice 1 (this work): the lever, DSP-inert.** Ship the full architecture with **both
`.guitar` and `.bass` policies set to today's exact constants**, plus persistence (§9) and the
guitar clamp (§10). The **accuracy benchmark must report identical numbers to `main`** for both
guitar and bass — the CI accuracy gate cannot break. The clamp is the one element *verified*
inert against the benchmark (not assumed), and reverted if any case regresses; persistence is
an intended UX change that does not touch the DSP path. Consolidates `M2`/`M3`/`M7`. Includes
unit tests proving the threading works (a profile with a different band plan changes windowing;
`.guitar` ≡ legacy).

**Expectation check — Slice 1 ships *zero perceptible bass improvement*.** Under option A the
free `.lock` default flip is also deferred, so at the end of this PR bass still "won't settle"
— and because persistence (§9) now restores the last instrument, a returning bass user launches
straight into the still-broken experience. This is the deliberate, defensible choice (clean
inert refactor first), but it is the crux of the user's actual goal, so the **PR description
must state plainly that this slice delivers no perceptible bass change** — nobody should merge
it expecting the symptom gone. (If one visible win is wanted, the bass `.lock` flip is one line
of pure UX — the user's call, not a gap.)

**Deferred to `docs/todos/` (the bass fix — pulling the lever):**
1. Tune `.bass.bands` so E1/A1 get the long window (root cause #1).
2. Tune `.bass` per-band confidence floors (root causes #2, #3).
3. Flip bass `defaultMode` to `.lock` (root cause #4).
4. Build the settle-stability verification harness (cents σ over a sustained window,
   lock-retention %, lock-drop count) on realistic/real-DI bass stimulus, then re-baseline.
   Also closes `medium-M17` (stress tests bypassing the full pipeline).

See `docs/todos/bass-detection-policy-tuning.md` and
`docs/todos/bass-settle-stability-harness.md`.

## 12. Testing strategy

- **Zero-delta gate:** the existing accuracy benchmark must report identical numbers for
  guitar and bass after Slice 1 (default `.guitar`/`.bass` policies == today's constants).
  **Confirm a Drop-C / C2 (65.4 Hz) guitar case is in the verification set** (or add one) — the
  60 Hz clamp's binding constraint is C2, so without it the gate goes green without ever
  exercising the constraint (false confidence).
- **New unit tests:**
  (a) **bidirectional f0 sweep** across all three band boundaries (235/265, 110/130, 35/45),
  asserting the new `[BandSpec]`-driven `nextConfig` picks the *same* band as `main`'s
  `switch`-based version going both up and down — this is what catches a stateful-hysteresis
  regression (a point check would not);
  (b) a synthetic policy with an altered band plan changes the chosen window at a known
  frequency (proves the plumbing is live, not hardcoded);
  (c) `lockConfidence(forFrequency:)` returns today's 0.75/0.9 split at 120 Hz and
  `sustainConfidence(forFrequency:)` returns uniform 0.6 — guards the app-layer parity the
  benchmark can't see (`PitchReadingStrobe` is outside the engine package);
  (d) `setDetectionPolicy` while running resets state without crash.
- **Settle-stability metric** is specified here but built in the deferred bass-fix work — the
  synthetic benchmark cannot observe "won't settle."

## 13. Decisions log

- 3-layer split (not a shared-core package). ✔
- Per-band confidence floors (preserves guitar low strings exactly). ✔
- `emitFloor` is a policy scalar (not per-band, dual-used in `PitchDetector`), defaulted to 0.5
  so the bass fix is pure value-tuning without re-opening the type. ✔
- Band transitions pinned to `floorHz ± hysteresisHz` semantics + exact guitar value table, so
  the flat `[BandSpec]` reproduces the stateful `switch` bit-for-bit. ✔
- Built-in profiles code-defined, not persisted; `DetectionPolicy` not `Codable`. ✔
- Slice 1 DSP-inert — bass `.lock` default flip deferred (option A); PR description must state
  no perceptible bass change. ✔
- Persist last-used instrument/tuning. ✔
- Guitar clamp floor ~60 Hz (below Drop C C2 = 65.4 Hz), zero-delta-verified or reverted. ✔
- Preserve zero accuracy-benchmark delta in Slice 1. ✔
