# Capture rules

- Use `.measurement` AVAudioSession category mode — no AGC. Standard mode degrades pitch accuracy by modifying gain.
- Prefer wired DI/interface; mic is the fallback. Input selection is `.auto` by default. Do not hardcode `.mic`.
- The audio tap does **one thing**: copy samples into the ring buffer. No DSP, no allocation, no locking on the audio thread. Wall-clock reads must use `CACurrentMediaTime()` (direct `mach_absolute_time` wrapper, RT-safe) — not `ProcessInfo.processInfo.systemUptime` (ObjC message send, not RT-safe). The `#else` Linux fallback path in `TunerEngine.swift` uses `systemUptime` only because QuartzCore is unavailable there; no real-time audio tap executes on Linux.
- Guard all AVAudioEngine/AVAudioSession code with `#if canImport(AVFoundation)`. The DSP pipeline tests run headlessly on Linux CI without this framework.
- AVAudioSession options/symbols must exist in **CI's** build SDK, not just your local one. `#if os(iOS)` code is type-checked in CI only by the `iOS Simulator` `xcodebuild` step — never by `swift test` or the macOS build — so a newer-SDK symbol (e.g. `.allowBluetoothHFP`, the iOS-26 rename of `.allowBluetooth`) compiles on a newer local Xcode but red-lights CI on the older one. Use the spelling that exists in the lowest SDK you build against; `#available` gates *runtime* availability, not *symbol existence*. See `docs/solutions/best-practices/ios-only-code-ci-sdk-skew-2026-06-16.md`.
- Audio is processed entirely on-device and **never recorded, stored, or transmitted**. Do not add any persistence or network calls to the capture path.
- Microphone permission is requested lazily on first `start()`, not at app launch.
- On macOS sandboxed/notarized builds, the `com.apple.security.device.audio-input` entitlement is required. It is present in `Guitar_Tuner.entitlements`.
- If `AVAudioEngine` throws on start, surface the error via `TunerEngineError` — do not silently swallow it.
- Scratch buffers must be pre-allocated to the maximum expected frame count (4096 covers all iOS/macOS buffer sizes at 44.1/48 kHz); clamp every read/write with `let safeFrames = min(frames, scratch.count)` — never resize on the RT thread.
