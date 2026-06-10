# TunerEngine — full engine audit (2026-06-10)

Scope: everything that produces or transports a pitch reading — the DSP core
(`Packages/TunerEngine/Sources/TunerEngine/`), the benchmark/diagnosis harness
(`Bench/`), capture (`Capture/`), and the app-side engine glue (`App/Engine/`).
Method: line-by-line review with the math re-derived independently (not trusted
from comments), the full test suite (86 tests) and the release-mode accuracy
benchmark run headless on Linux, and findings cross-checked against the
literature (McLeod 2005, de Cheveigné/Kawahara 2002 YIN, Candan 2013,
Kay eq. 3.41, RBJ cookbook).

## Verdict

The DSP core is in excellent shape: every algorithm checked matches its
published formulation, the octave-safety architecture (MPM as sole octave
authority, refiners clamped to ±50¢) is sound and enforced by tests, and the
measured accuracy matches the committed spec. The audit found **one real math
bug in the benchmark harness** (the CRLB constant — fixed in this PR), **one
user-visible engine API bug** (stop→start permanently killed the readings
stream — fixed in this PR), and a set of capture/app-lifecycle gaps (audio
session ownership, interruption/route-change handling) that are recommended
follow-ups, not regressions.

## Verified correct (independently re-derived)

| Area | What was checked |
|---|---|
| `Autocorrelation.swift` | `m(τ) = P[N−τ] + P[N] − P[τ]` prefix-energy identity (exact); NSDF `2r/m`; YIN `d = m − 2r`; parabolic vertex offset *and* value formulas. |
| `PitchDetector.swift` | MPM key-maxima walk + `k = 0.9` threshold per McLeod; YIN CMNDF, absolute-threshold + dip-descent, parabolic refine; hybrid octave tie-break prefers the lower fundamental. Lag bounds honour `range` and window. |
| `FrequencyInterpolator.swift` | Candan-2013 `δ = (N/π)·atan(tan(π/N)·Re q)` with the correct `q` sign convention for `X(k)=Σx·e^{−j2πkn/N}`; log-parabolic (Gaussian/Hann) estimator; all outputs clamped to ±0.5 bin, NaN-safe. |
| `SpectralAnalyzer.swift` | Complex-oscillator DTFT recurrence (error ~O(N·ε) in Double — fine at N=4096); 5-bin local-peak deferral; ±50¢ octave-safe clamp; `k ≥ 2`, `k ≤ N/2−2` guards; rectangular frame for Candan, Hann copy only on the fallback path. |
| `StrobePhase.swift` | Global-clock phase referencing (stationary on pitch — verified algebraically), mod-1 reduction *before* subtraction for long-session precision; phase-vocoder `f + fs·princarg(Δφ−2πf·hop/fs)/(2π·hop)`; `princarg` wraps to (−π, π] correctly; bass-band hop (1024 @ 48 k) keeps the ±23.4 Hz unwrap bound comfortably. |
| `Preprocess.swift` | RBJ 2nd-order Butterworth HP coefficients (exact match); transposed DF-II update; DC blocker pole at ~5 Hz; 28 Hz cutoff costs low B (30.87 Hz) only ~2 dB — acceptable, and stateful filtering avoids window-edge transients. |
| `PitchPipeline.swift` | Hop scheduling independent of caller chunk size; raw frames for NSDF/YIN + Candan (correct), Hann-windowed copy for strobe phase (correct); band hysteresis (110/130, 235/265) can't chatter; phase-vocoder only fires when frame geometry matches; unvoiced streak resets to acquire. |
| `Smoothing.swift` | Median+EMA in log-frequency (MIDI) domain; 120¢ snap resets both stages; sustain gate streak logic. |
| `Note.swift` | MIDI↔Hz conversions; negative-MIDI name indexing; octave = ⌊midi/12⌋−1; cents in [−50, 50]. |
| `RingBuffer.swift` | SPSC ring: monotonic absolute indices, power-of-two mask, drop-oldest overflow, oversize-write tail-keep — all correct; Linux `NSLock` fallback correct. |
| `TunerEngine.swift` | Actor isolation, capture lifecycle, pipeline fed the *hardware* sample rate. |
| Capture (`AudioCapture`, `MicrophonePermission`) | `.measurement` mode (AGC off — right for a tuner); tap downmix math; hardware-format sample rate; iOS-17 `AVAudioApplication` permission path, continuation resumed exactly once. |
| `ToneSynth.swift` / `ToneGenerator` render path | Continuous phase accumulator across retunes (no clicks); one-pole gain glide; amplitude-sum normalisation (can't clip); ABL channel duplication. |
| Bench harness | Cents math (incl. 1200/ln2 ≈ 1731 linearisation, 1¢ ≈ 577.8 ppm); stiff-string partials `k·f0·√(1+B·k²)` consistently in synth + probe D (whose (n², (f/n)²) regression is algebraically exact); vibrato/glide FM integrates phase per sample (correct, not `sin(2πf(t)t)`); Box–Muller + SplitMix64 noise, deterministic seeding; SNR convention consistent end-to-end; WAV codec field parsing/alignment/sign-extension; lock-window scoring guards empty windows. |
| Strobe consumption (app side) | `phase` units (cycles 0…1) consistent through `PitchReadingStrobe` → renderers; `wrappedDelta` (`d −= d.rounded()`) is the correct shortest-path phase delta; lock thresholds (±3¢, 0.9) agree between engine and app. |

Empirical cross-check (release benchmark, this machine): pure/harmonic tones
track to *hundredths* of a cent in the core range; zero octave errors across
all families including weak/missing-fundamental stress cases; the inharmonic
family's constant ≈ +0.26¢ offset is the stiff string's real first partial
(`√(1+B)`), not an engine bias.

## Bugs found and fixed in this PR

1. **CRLB constant was 2× too small** — `Bench/Crlb.swift`.
   The code used `6·fs²/((2π)²·SNR·N(N²−1))` with SNR = A²/2σ². For a **real**
   sinusoid the bound (Kay eq. 3.41; re-derived here from the Fisher matrix
   with the φ-coupling term) is `12·fs²/((2π)²·SNR·N(N²−1))`; 6 belongs to the
   complex-exponential case. Reported floors were √2 ≈ 1.41× too optimistic and
   the "σ / harmonic floor" efficiency column ~41% inflated. Fixed constant +
   doc comments; updated the pinned probe-C test values (0.0150→0.0212¢,
   0.000765→0.001081¢ — the √385 single/harmonic ratio is unaffected) and the
   plan docs/report quoting them. *Engine accuracy itself is untouched — this
   only made the gap-to-physics look bigger than it is.*

2. **Stop→start permanently killed the readings stream** — `TunerEngine.swift`.
   The single `AsyncStream` was created once in `init`; cancelling the
   consuming task (which is exactly what `LiveTunerModel.stop()` does) finishes
   an `AsyncStream` forever, so after one stop the next start showed
   "Listening" but never delivered a reading again. `readings` now mints an
   independent stream per access (continuations multicast from the consume
   loop, removed on termination); `LiveTunerModel` updated for the now
   actor-isolated property.

3. **`Diagnosis.probeB` ignored its `centerBin` parameter** — bins 199–201 were
   hardcoded; any caller passing a non-default `m0` got garbage. Now uses `m0`.

4. **Unsupported WAV formats decoded as silence** — `Fixtures.decodeWAV`
   accepted e.g. 8-bit PCM or float64 through its guards and `sample()`'s
   `default: return 0` produced an all-zero "fixture" that would be *scored*
   instead of skipped. Unsupported (format, bits) pairs are now rejected.

5. Comment fix: the 600¢ octave-error threshold is a tritone, not
   "quartertone×6" (`Bench/Metrics.swift`).

## Open findings (recommended, not fixed here)

Ordered by impact; none is a regression from the recent P0/P1 work.

**Capture/session lifecycle (iOS) — the biggest real-world gap.**
- `AudioCapture` and `ToneGenerator` both configure the shared
  `AVAudioSession` (`.record` vs `.playAndRecord`): starting capture while the
  reference tone plays silences it; `AudioCapture.stop()` deactivates the
  session out from under the tone. One owner should configure a single
  `.playAndRecord` + `.measurement` session.
- No handlers for interruption / route change / `AVAudioEngineConfigurationChange`
  / media-services reset. A phone call leaves the UI saying "Listening"; a
  route change can alter the hardware sample rate while the pipeline keeps the
  stale one — confidently wrong readings (44.1 vs 48 kHz ≡ ~147¢). A tuner hits
  these constantly (headset/DI plug-unplug). Rebuild the pipeline from the new
  format on `AVAudioEngineConfigurationChange`.
- Tap installed without validating the input format; a degenerate format
  (0 Hz/0 ch — possible on Macs with no input) raises an uncatchable ObjC
  exception. Guard and throw `engineStartFailed` instead.
- A failed `engine.start()` leaks the activated session and installed tap.
- `.allowBluetooth` admits narrowband HFP mics — at odds with the
  "strobe-grade" input goal; drop it or fold BT into the input-preference logic.
- macOS: `ENABLE_HARDENED_RUNTIME: YES` with no `.entitlements` file means mic
  capture will be denied regardless of `NSMicrophoneUsageDescription` — add
  `com.apple.security.device.audio-input`.

**App/engine glue.**
- `LiveTunerModel.stop()` fires `Task { await e.stop() }` unstructured; a fast
  stop→start can execute on the actor as start-then-stop, leaving the UI
  "Listening" with a stopped engine. Same pattern for the setter calls (two
  rapid string taps can land out of order). Serialize these through one task.
- `ToneGenerator.stop()` never detaches its `AVAudioSourceNode`; a later
  `start()` attaches a second node sharing the same renderer (double phase
  advance). Latent — nothing calls `stop()` today — but fix before anything does.
- `setMode(.lock)` selects a string but doesn't retune a sounding reference
  tone (`updateTone()` not called).
- `Haptics` reset handler touches `@MainActor` state from a CoreHaptics queue
  (Swift 6 strict concurrency would reject it).
- `ToneRenderer` uses `NSLock` (no priority donation) on the render thread;
  use `OSAllocatedUnfairLock` like the capture ring.

**Real-time hygiene (bounded, but worth tightening).**
- `SampleRingBuffer.read()` allocates the output array *while holding* the
  lock the audio thread contends on; allocate before locking. (The doc comment
  also promises "memcpy" while both copies are per-element masked loops —
  bounded and correct, just not what the comment says.)
- `AudioCapture`'s `scratch` buffer grows via allocation inside the tap
  callback on first use / buffer-size growth; preallocate at `start()`.
- `PitchPipeline.recent()` does two modulos per sample per hop and
  `process(_:[Float])` forces callers to materialise arrays
  (`Array(signal[i..<end])` per block in the bench); an
  `ArraySlice`/`UnsafeBufferPointer` overload + two-segment copy would cut
  steady-state allocations.

**Benchmark harness robustness (latent, currently unreachable).**
- `Diagnosis.phaseSlope` traps on < 2048 samples; xorshift seed 0 is a fixed
  point (probe A noise becomes a DC constant); `probeD(partials: 1)` divides
  by zero; `Metrics.centsError` would propagate NaN through gates silently if
  the pipeline ever emitted f ≤ 0 (NaN compares false — a NaN would *pass* CI).
  Cheap guards worth adding next time the harness is touched.
- `crlbSection` hardcodes `f0 = 82.41` and matches noise cases by frequency;
  a non-440 `a4` run would silently mismatch.
- Noise-robustness results are reported but not gated by `--ci`.

**Minor / observations.**
- `PitchDetector.hybrid`'s octave window is asymmetric in cents (ratio−2 < 0.06
  ≈ ±50¢ vs ratio−0.5 < 0.03 ≈ ±100¢); harmless, but probably meant to match.
- `Windowing.hann` is the symmetric (N−1) form; the measured interpolator bias
  constants assume exactly this window, so it's consistent — just don't swap
  in a periodic Hann without re-running the probes.
- `PitchReading.isLocked` defaults to confidence ≥ 0.9 while the pipeline's own
  comments put inharmonic low-string clarity at ~0.7–0.85; if real-string lock
  feels unreachable on low E/A, this threshold is the first knob to check.
- Pooled "jitter σ" in the report mixes per-case bias with per-reading jitter
  (overstates jitter); the per-case CSV σ is the honest number.
- `LiveTunerModel`'s watchdog uses wall-clock `Date()`; a clock change can
  blank/freeze readouts — use `ContinuousClock`.
- `TunerEngine.consume()` polls every 4 ms even in silence (battery).

## How this was validated

- `swift test` (86 tests) green on Linux before and after the fixes, including
  the re-pinned CRLB probe values.
- `swift run -c release Benchmark` re-run after the fixes: all `--ci` gates
  pass; only the CRLB floor / efficiency columns moved (by exactly √2), as
  predicted; engine accuracy numbers unchanged.
- The committed `docs/benchmarks/accuracy.md` CRLB section was regenerated to
  match the corrected bound.
