# Pipeline rules

- `PitchPipeline` is the testable DSP core. It has no AVAudioEngine dependency. Drive it directly in tests with synthesized/file samples. Do not entangle DSP logic with capture.
- `TunerEngine` is the `public actor`. It owns capture + concurrency + the `AsyncStream<PitchReading>` delivery. Keep its public surface minimal — callers need `start()`, `stop()`, `readings`, `setA4()`, `setTargetNote()` and nothing else.
- `SampleRingBuffer` is RT-safe. No locking, no allocation on the write path (the audio thread). Do not add any blocking operations to the ring buffer.
- `ToneSynth` is **phase-continuous**. Never reset the synthesis phase between frequency changes or on/off transitions — phase discontinuities produce audible clicks. The phase is held across calls by design.
- The `AsyncStream` is single-consumer. One `Task` reads `engine.readings`. Do not add multiple concurrent consumers.
- Drive `PitchPipeline` directly in tests — no audio device required. Use `TunerEngine/Bench/Stimulus` for synthesized tones, `Fixtures` for file-based regression inputs.
- On platforms without live capture (headless CI), `engine.start()` throws `.captureUnavailable`. This is expected; tests drive `PitchPipeline` directly.
