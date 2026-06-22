# Design — DEBUG-only Real-Instrument Session Recorder (mono v1)

- **Date:** 2026-06-22
- **Status:** Approved (brainstorm) → ready for implementation plan
- **Domains:** `pipeline` (engine emission), `swiftui` (app recorder + UI), `dsp`/`testing` (codec + determinism), `security` (persistence, co-injected)
- **Branch:** `feat/session-recorder`

## 1. Motivation

Every accuracy number LUMA reports — 0.23 ¢ clean mean, 0.59 ¢ low-bass, 0.00 % octave
errors — is measured against **synthesized** stimuli (`Bench/Stimulus.swift`). The headless
real-DI fixture harness (`Bench/Fixtures.swift`: WAV loader + `CaseRunner` scorer +
`Benchmark --fixtures`) exists and is tested, but **holds zero real recordings** — no
`.wav`/`.aif` anywhere in the package. The engine has never been scored on a real string
with real inharmonicity, pluck transients, body resonance, or fret noise.

Separately, the app has **no live-reading instrumentation**: the only CSV/export path is the
headless `Benchmark` tool. On a real device today you can watch the strobe but cannot get
numbers out of it.

This feature closes both gaps with the smallest, lowest-risk build that yields a
**methodologically valid absolute accuracy number on real strings**, and it feeds the
existing scoring back-end rather than replacing it.

## 2. Goals / Non-goals

**Goals**
- Capture a real-instrument take, on-device, through the **existing mono capture path**.
- Produce a `Fixtures`-compatible WAV (named with its true frequency) + a per-hop readings CSV.
- Export both off-device for scoring via the unchanged `Benchmark --fixtures` path.
- Keep the entire capability **`#if DEBUG`** — the shipped release has zero recording surface.
- Add a determinism guard: an offline replay of a recorded WAV reproduces the live pipeline output.

**Non-goals (v1)**
- Simultaneous dual-channel reference capture (phase 2, §9 — test-gated).
- Any change to the real-time audio tap (`AudioCapture.ingest`).
- Any release-build behavior, Info.plist file-sharing keys, or `PrivacyInfo.xcprivacy` change.
- Absolute sub-0.05 ¢ truth (requires a precision injected reference — phase 2).
- Committing recorded audio to the repo or to CI (fixtures stay local, per `Fixtures.swift:7`).

## 3. What this validates — and what it does NOT claim

Ground truth comes from the **filename convention** (`Fixtures.parseTrueFrequency`):
`<label>_<trueHz>.wav` (e.g. `E2_82.41.wav`) or `<note>.wav`. The filename Hz is the
**nominal** note. A real plucked string is only at the nominal pitch if it was tuned there.

The methodology that makes filename-truth valid for **absolute** accuracy requires the reference
to confirm the string is at pitch **on the same signal, at the moment of capture** —
*verify-at-capture, not verify-then-hope*. The robust rig is a **passthrough reference-grade
strobe tuner in the signal chain** (instrument → strobe → DI → device): it reads the exact signal
being recorded, so "strobe showed 0.0 ¢" is contemporaneous with the take. Tune to the
**independent** strobe (±0.1 ¢; Sonic Research Turbo Tuner, Peterson StroboStomp), *not* to LUMA
itself (that would be circular). Then the nominal Hz is the true Hz to ±0.1 ¢ — 2–6× tighter than
the engine's measured error (0.23–0.59 ¢): a valid measurement (reference comfortably better than
the device under test).

A strobe **app on a spare phone** is fine for *behavioral* takes but is **not** valid for the
absolute number unless the signal is split so the phone reads it concurrently. Tuning on the phone
and then moving the cable to the recording device leaves the pitch **unverified during the take**,
and short-term drift (temperature, fresh strings, low B/E settling) can silently exceed 0.1 ¢ and
quietly invalidate the result this feature exists to produce.

- **Validated:** absolute cents error, σ, lock σ, time-to-lock, octave-safety, and robustness
  to real pluck transients / inharmonicity / body resonance on real strings — the failure
  modes synthetic tones cannot reproduce.
- **Not claimed:** sub-0.05 ¢ absolute. That floor is set by the ±0.1 ¢ reference and would
  require an injected precision source (phase 2). Absolute sub-cent behavior remains
  characterized by the synthetic CRLB analysis.

### Why not simultaneous dual-channel capture (decision record)

A simultaneously-captured known reference cancels the device sample-clock error exactly in the
ratio `f_inst_true = f_ref_true × (f_inst_meas / f_ref_meas)` (both channels share the clock).
**But** the clock error is only ~0.076 ¢ at 44 ppm and `ClockCalibration` already corrects most
of it, while the ratio *injects the pipeline's measurement noise on the reference channel*
(~0.1–0.2 ¢/hop) — net-negative unless the reference is measured with a long-window estimator
that drives its noise well below the clock term. That premise is unproven, and the capture
requires surgery on the project's single most safety-critical code (the RT tap). Decision:
defer to phase 2 behind a zero-hardware feasibility test (§9). Mono + an independent ±0.1 ¢
strobe gets the same absolute truth for near-zero new capture code and zero RT risk.

## 4. Architecture

Clean-separation preserved: the engine emits data, the **app** persists it. No file I/O and
no networking enter `TunerEngine`. All additions below are `#if DEBUG`.

| Component | File | Responsibility |
|---|---|---|
| Engine raw-sample emission | `Packages/TunerEngine/Sources/TunerEngine/TunerEngine.swift` | `#if DEBUG`: `rawSamples: AsyncStream<[Float]>` minted with **lossless** buffering (`.unbounded`), plus `setRecording(_ on: Bool)` gating whether `consume()` yields. Yielded from `consume()` immediately after `ring.read()` (`:189–191`) — the exact post-downmix mono the pipeline consumes. Single consumer (the recorder). No yield when not recording. |
| `SessionRecorder` | `App/Engine/SessionRecorder.swift` (new) | `#if DEBUG`. Accumulates sample blocks + raw `PitchReading`s in memory; tracks running **peak amplitude + clipped-sample count** for the UI meter; soft cap ~5 min (≈ 57 MB mono Float32 @ 48 kHz) — stop + warn at the cap. On stop, encode Float32 WAV + CSV off the main actor, return file URLs. |
| Float32 WAV encode | `Packages/TunerEngine/Sources/TunerEngine/Bench/Fixtures.swift` | Extend `encodeWAV` (currently 16-bit PCM only) with a Float32 path (format 3 / 32-bit). Bit-exact round-trip; one codec; lives in the engine package so the headless side shares it. `decodeWAV` already reads float32. |
| `LiveTunerModel` wiring | `App/Engine/LiveTunerModel.swift` | `#if DEBUG`: owns `SessionRecorder?`; `startRecording()` / `stopRecording() -> [URL]`; on record-start calls `engine.setRecording(true)` and spawns a task draining `engine.rawSamples` into the recorder; `apply(r:)` (`:244`) tees the **raw** `PitchReading` into the recorder CSV; supplies session context. |
| Recorder UI | `App/LiveTunerScreen.swift` (existing `#if DEBUG`, `:247`) | Record toggle; **live peak-level meter + clip counter** while recording (AGC is off under `.measurement`, so a hot DI can clip silently and score as garbage — the meter lets you reject + redo a bad take); on stop, a confirm/override sheet for the truth label; `UIActivityViewController` share-sheet export. No Files-app Info.plist keys. |
| Determinism test | `Packages/TunerEngine/Tests/TunerEngineTests/` | §7. Pure, headless. |

### Data flow
```
[mic/DI] → AudioCapture.ingest (mono downmix) → ring
  → TunerEngine.consume(): samples = ring.read()
       → pipeline.process(samples) → readings ─→ readings stream → LiveTunerModel.apply()
       │                                                            └─ tee RAW reading → recorder CSV
       └─ #if DEBUG && isRecording: yield samples → rawSamples → recorder accumulates
  → stopRecording(): flatten → Float32 WAV (Fixtures.encodeWAV) + CSV → Documents → share sheet
  → developer drops WAV in docs/benchmarks/fixtures/ → swift run Benchmark --fixtures → accuracy.md
```

## 5. File & naming contract

- **WAV:** `Fixtures` convention. **Lock mode** auto-pre-fills `<note>_<nominalHz>.wav` from the
  target string (the truth once tuned to the external strobe). **Auto/chromatic mode requires an
  explicit note** on the confirm sheet — true Hz is undefined without a target. An override text
  field allows a non-standard label/Hz. Validate the final name parses via
  `Fixtures.parseTrueFrequency` before writing.
- **WAV format:** mono, Float32, capture sample rate (typ. 48 kHz). Bit-exact to the live
  pipeline input.
- **CSV sidecar:** `<label>.csv`.
  - Header block (commented `#` lines): instrument, tuning id, a4, `correctionFactor` at capture,
    sampleRate, device model, reference note, capture ISO-8601 timestamp, app/engine version.
  - Columns (one row per hop): `timestamp,frequency,note,cents,confidence,phase,inharmonicityB,precisionCents,isLockIntegrated`.
  - Values are the **raw** `PitchReading` (NOT clock-corrected, NOT lock-mode-relative) — so the
    live log reconciles with an offline `Benchmark` replay (which runs without `ClockCalibration`).
    Never diff corrected-live cents against raw-replay cents.
- **Location / export:** app `Documents`, exported via share sheet. Recorded audio is
  out-of-CI and not committed; scoring results land in `docs/benchmarks/accuracy.md`.

## 6. Privacy / security boundary

- All recording code — engine `rawSamples`/`setRecording`, `SessionRecorder`, UI, share-sheet —
  is `#if DEBUG`. The release binary contains **no recording API**, no file-sharing Info.plist
  keys, and an unchanged `PrivacyInfo.xcprivacy`. "Audio never leaves the device" is preserved:
  the engine still does no I/O and no networking; a DEBUG-only app affordance persists locally
  under explicit developer action, exported only via an explicit share-sheet gesture.
- Flag the `security` domain reviewer (persistence) even though DEBUG-gated.

## 7. Testing / verification

- **Determinism round-trip (headline correctness guard):** for a synth signal `s`, readings from
  `freshPipeline.process(decodeWAV(encodeWAV(s)))` **exactly equal** readings from a *separate*
  `freshPipeline.process(s)`. Exact equality (no tolerance) is the point: bit-exact Float32
  round-trip + a deterministic pipeline ⇒ identical readings. Decomposes into the two properties
  below; this combined assertion is what guards against hidden time/clock state leaking into the
  pipeline. Pure, no hardware. (16-bit would force a tolerance — the reason v1 uses Float32.)
- **Codec round-trip:** Float32 `decodeWAV(encodeWAV(s)) == s` bit-exact; existing 16-bit path unchanged.
- **Pipeline determinism:** two fresh `PitchPipeline`s fed identical samples yield identical readings.
- **Naming:** round-trip names through `Fixtures.parseTrueFrequency` (lock-mode auto-name +
  override + auto-mode-requires-note).
- **Clip/peak tracking:** a synthetic over-unity buffer raises the recorder's clip counter and peak.
- **Regression:** existing `FixturesTests`/`StimulusTests` + full `swift test` stay green;
  accuracy benchmark gate unaffected (no DSP change).
- **Manual on-device (developer):** record a strobe-tuned string, export, drop in
  `docs/benchmarks/fixtures/`, `swift run Benchmark --fixtures`, confirm a sane absolute number.

## 8. Acceptance criteria

1. Release build: `grep`-able proof that `rawSamples`, `setRecording`, and `SessionRecorder`
   are absent from a non-DEBUG compilation; no new Info.plist/privacy-manifest keys.
2. A DEBUG on-device session yields a `<note>_<hz>.wav` + `<label>.csv` that
   `Benchmark --fixtures` scores without modification.
3. Determinism + codec round-trip tests pass; full `swift test` green on both packages.
4. The RT tap (`AudioCapture.ingest`) is byte-for-byte unchanged.

## 9. Phase 2 — simultaneous dual-channel (designed-for, NOT built)

Additive on top of v1. **First step is a zero-hardware synthetic feasibility test**: synthesize
instrument + reference tones, inject a realistic clock error ε into *both* channels plus
realistic per-hop noise, measure the reference with a long-window estimator, and verify
ratio-recovery beats mono + `ClockCalibration`. Build the capture path **only if it passes**.

If built: **DC-A** — in DEBUG + recording, tee the tap's full multi-channel buffer *before*
downmix to an off-thread writer, write per-channel mono WAVs (`instrument.wav` + `reference.wav`,
shared timestamp); engine analyzes channel 0 for live display. Reuses the mono codec per file
(sidesteps `decodeWAV`'s stereo downmix). Add a reference-relative scorer in `Bench/`. The v1
file format already leaves additive slots: a `reference.wav` sibling and a `referenceHz` CSV
field. Requires a precision injected source (function generator / disciplined oscillator) and a
2-in class-compliant USB interface.

## 10. Risks / open questions

- **Unbounded stream growth** if the recorder consumer stalls — mitigated by the in-memory soft
  cap and the consumer being a trivial append; revisit if long sessions are needed (stream to disk).
- **Sample/reading alignment:** v1 treats the WAV as the authoritative artifact (re-scored
  offline); the CSV is the live-reference log. Tight sample-accurate alignment is not required for
  v1 scoring.
- **A4 / non-standard tunings:** naming uses nominal-at-current-a4; the override field covers
  deliberate offsets. Confirm the lock-mode pre-fill uses the engine's active a4.

## 11. Implementation notes (for the plan)

Gotchas surfaced in review — carry into writing-plans:

- **Cancel the drain task on stop.** The `rawSamples` stream does not finish on its own;
  `stopRecording()` must cancel the task draining it (mirror `readTask?.cancel()` at
  `LiveTunerModel.swift:133`) or the `for await` hangs.
- **Bound *both* buffers.** The ~5 min soft cap must bound the `.unbounded` `rawSamples` backlog,
  not only the recorder's accumulation array — they are separate buffers. When the cap trips, call
  `engine.setRecording(false)` to stop the yield at the source.
- **No clamp on the Float32 write.** The Float32 `encodeWAV` path must NOT inherit the 16-bit
  clamp `max(-1, min(1, s))` — clamping is wrong for a lossless float write and would break the
  bit-exact round-trip for an over-unity sample. Keep the clamp on the 16-bit path only.
