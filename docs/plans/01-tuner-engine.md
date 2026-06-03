# Plan 01 — `TunerEngine` (DSP + benchmark harness)

> Execute in its own session. Produces the shared, UI-free audio + DSP package and the
> accuracy benchmark — the product's reason to exist (`DESIGN.md` §1, §3).

## Goal
A shared Swift package, **`TunerEngine`**, that turns live audio into a stream of precise
pitch readings — nearest note, **cents**, confidence, and **phase** (to drive the strobe) —
plus a **benchmark harness** that measures real accuracy so we publish the spec from data,
not guesses.

## Prerequisites & references
- `DESIGN.md` §3 (the accuracy engine), §5 (architecture / stack)
- `docs/EXPERIENCE.md` §2 (the strobe consumes `phase`)
- Posture: **best achievable on-device; measure, don't guess.**

## In scope
Audio capture · the pitch pipeline · the public API · unit tests · the benchmark harness.

## Out of scope
Any UI · tuning-preset / string-lock UI (engine is chromatic + an optional target hint) ·
networking (none, ever, in v1).

## Plan

### 1. Package skeleton
- Swift Package `TunerEngine` (library). Targets: `TunerEngine`, `TunerEngineTests`,
  `Benchmark` (executable or test target). Pure Swift + **Accelerate / vDSP**; no third-party
  deps. Platforms align with the OS floor once set.

### 2. Capture (`AVAudioEngine`)
- Mono, **48 kHz**, small buffers (~1024–2048 frames); tap the input node.
- **Prefer a wired DI / interface:** iOS via `AVAudioSession` preferred input + `.measurement`
  mode (disable AGC/processing); macOS via input-device selection. Mic is the fallback.
- Mic-permission handling; copy states audio never leaves the device.
- **Real-time safety:** the tap only copies samples into a **lock-free ring buffer**; all
  analysis runs off the audio thread.

### 3. Pitch pipeline
```
ring buffer → frame (window + hop) → DC block + high-pass (~25–30 Hz)
  → MPM/NSDF (or YIN) fundamental → parabolic interpolation (sub-sample period)
  → phase-vocoder instantaneous freq (sub-cent + strobe phase)
  → confidence + sustain gate → median/EMA smoothing
  → frequency → MIDI note + cents (A4 reference)
```
- **Fundamental tracking (octave-safe):** MPM via NSDF and/or YIN. Track the **fundamental** —
  strings are slightly **inharmonic**, so "tallest FFT peak" biases sharp. MPM vs YIN vs
  hybrid is decided by the benchmark.
- **Sub-cent:** parabolic interpolation around the NSDF peak; phase-vocoder phase-advance
  between hops for fine instantaneous frequency — that **phase is exactly what the strobe
  needs.**
- **Confidence + sustain gate:** gate on NSDF peak height; skip the noisy pluck attack, lock
  onto the stable sustain.
- **Smoothing:** short **median + EMA** — kill jitter without perceptible lag.

### 4. Range / latency strategy
- Low B (~31 Hz, ~32 ms period) needs ~2–3 periods → settles **~100–150 ms** (document as
  "rock-solid," not laggy). Use a **longer window for low strings, shorter for high**, with
  overlapping hops so guitar / high notes stay snappy. Tabulate window/hop per range.

### 5. Public API (sketch)
```swift
struct PitchReading {
  let frequency: Double; let note: Note; let cents: Double
  let confidence: Double; let phase: Double; let timestamp: TimeInterval
}
actor TunerEngine {
  var readings: AsyncStream<PitchReading> { get }
  func start() async throws;  func stop()
  var a4: Double { get set }            // 430…450, default 440
  var inputPreference: InputPreference  // .auto / .di / .mic
}
```
Chromatic by default; an optional `targetNote` hint can tighten gating for string-lock.

### 6. Benchmark harness (the point)
- **Stimuli:** synthesized tones (pure, harmonic, and **inharmonic** string models) at known
  freq + cents; recorded **DI** of tuned strings; noise / SNR sweeps.
- **Metrics:** cents error (mean / abs / σ) across the full guitar + bass range,
  **time-to-lock**, **octave-error rate**, robustness vs SNR.
- **Output:** a CSV + Markdown report → the published accuracy spec (`DESIGN.md` §3).
- Runs **headless** (XCTest or CLI).

### 7. Tests
Synthesized signals with known cents → assert error bounds; **octave-safety** on low bass;
noise robustness; steady-tone stability (no jitter beyond N cents).

## Definition of done
`TunerEngine` builds; emits `PitchReading`s from live + file input; tests green; the
benchmark produces a measured-accuracy report we can quote.

## Open questions (resolve in-session)
MPM vs YIN vs hybrid · exact window/hop per range · confidence thresholds · where to source
recorded DI samples · how `phase` is normalized for the strobe contract (coordinate with
Plan 03's `StrobeInput`).

## Kickoff prompt
> Read `DESIGN.md` (§3, §5), `docs/EXPERIENCE.md`, and `docs/plans/01-tuner-engine.md`.
> Implement the `TunerEngine` Swift package per that plan — AVAudioEngine capture
> (mono/48k, prefer DI), the MPM/YIN + phase-vocoder pipeline with confidence/sustain gating
> and smoothing, the `PitchReading` async API — plus the benchmark harness, tests, and an
> initial measured-accuracy report. No UI.
