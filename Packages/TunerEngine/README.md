# TunerEngine

The shared, **UI-free** audio + DSP package (Plan 01): it turns live (or file /
synthesized) audio into a stream of precise `PitchReading`s — nearest note,
**cents**, confidence, and the **strobe phase** — plus a headless **accuracy
benchmark**. Pure Swift + Accelerate/vDSP, no third-party deps, **no networking**.
Platforms: iOS 17 / macOS 14 (matches the app).

It has **no dependency on `LumaDesignSystem`** — it emits `PitchReading`; the app
layer maps that to the strobe's `StrobeInput` (DESIGN §5). That keeps the engine
independently testable and benchmarkable.

## Public API

```swift
let engine = TunerEngine(a4: 440, inputPreference: .auto, method: .mpm)
try await engine.start()
for await r in engine.readings {
    // r.note, r.cents, r.confidence, r.phase, r.frequency, r.timestamp
}
engine.stop()
await engine.setA4(432)          // 430…450
await engine.setTargetNote(...)  // optional string-lock hint
```

`PitchReading.phase` is the **strobe contract**: a normalized **0…1 cycle
position** of the tracked fundamental measured against the nearest-note reference
oscillator. On pitch it stands still; off pitch it advances at the beat rate
(∝ the Hz error) — sharp one way, flat the other. The strobe scrolls by Δphase
between readings (a true strobe). The app maps `PitchReading → StrobeInput` and
renders with `AuroraStrobe(phaseScroll: true)`.

## Pipeline

```
capture (AVAudioEngine, on-device) → ring buffer (RT-safe hand-off)
  → DC block + high-pass (~28 Hz) → window (Hann)
  → MPM/NSDF (or YIN / hybrid) fundamental, octave-safe, parabolic-interpolated
  → phase-vocoder refine (sub-cent) + strobe phase
  → confidence + sustain gate → median + EMA smoothing
  → note + cents at the current A4
```

`PitchPipeline` is the capture-agnostic core: push samples, get readings. **This**
is what the tests and benchmark drive headlessly — no audio device, no
concurrency — so CI runs the whole thing on synthesized / file input. The
`TunerEngine` actor just adds `AVAudioEngine` capture + the `AsyncStream`.

### Window / hop per range (48 kHz)

| Band    | f0        | Window        | Hop          | Overlap | Notes                       |
|---------|-----------|---------------|--------------|---------|-----------------------------|
| high    | ≥ 250 Hz   | 1024 (21 ms)  | 256 (5.3 ms) | 75 %    | snappy high strings         |
| mid     | 120–250 Hz | 2048 (43 ms)  | 512 (11 ms)  | 75 %    | guitar mids                 |
| low     | < 120 Hz   | 4096 (85 ms)  | 1024 (21 ms) | 75 %    | low E/A, low B, bass        |
| acquire | cold start | 4096 (85 ms)  | 1024 (21 ms) | 75 %    | octave-safe cold acquisition|

Low B (~31 Hz, ~32 ms period) needs ~2–3 periods, so the lowest notes settle in
~100–150 ms — documented, not fought (DESIGN §3). Higher notes track on short,
overlapping windows.

## Run the tests + benchmark

```sh
swift test --package-path Packages/TunerEngine
swift run -c release --package-path Packages/TunerEngine Benchmark --compare \
  --out docs/benchmarks
```

The benchmark synthesizes pure / harmonic / **inharmonic** tones across the full
guitar+bass range at known cents (plus SNR sweeps), runs them through the real
pipeline, and writes [`docs/benchmarks/accuracy.md`](../../docs/benchmarks/) — the
measured spec quoted in DESIGN §3. It runs **headless** (CI runs it on every push).

## Live capture & permissions

`AVAudioEngine`, mono, the hardware's rate (it requests 48 kHz). On iOS it uses
`.measurement` mode (no AGC) and prefers a wired DI / interface; the mic is the
fallback. The tap only copies into a lock-safe ring; all DSP is off the audio
thread. Audio is processed **entirely on-device** and never recorded, stored, or
sent (DESIGN §6). Live capture runs **on-device only** — CI exercises the file /
synthesized paths instead.

> macOS on-device note: the mic needs `NSMicrophoneUsageDescription` (present) and,
> for a sandboxed/notarized build, the `com.apple.security.device.audio-input`
> entitlement. iOS uses the usage description.
