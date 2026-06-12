---
name: avaudioengine-capture
description: Use when writing AVAudioEngine audio capture code, installing or removing taps, handling AVAudioPCMBuffer callbacks, configuring audio sessions, or debugging audio pipeline errors like format mismatches, engine start failures, or tap callback crashes.
---

# AVAudioEngine Audio Capture

## Architecture

```
AVAudioSession (iOS only — global category/mode config)
  └── AVAudioEngine
        ├── inputNode          ← microphone input (hardware)
        │     └── installTap   ← real-time callback, called on audio thread
        ├── mainMixerNode
        └── outputNode
```

On macOS the engine uses the system default device; `AVAudioSession` does not exist.

## Minimal Capture Setup

```swift
import AVFoundation

actor AudioCapture {
    private let engine = AVAudioEngine()
    private var continuation: AsyncStream<[Float]>.Continuation?

    func start() async throws -> AsyncStream<[Float]> {
        // iOS only: request permission + set session category
        #if os(iOS)
        try AVAudioSession.sharedInstance().setCategory(.record, mode: .measurement,
                                                        options: .duckOthers)
        try AVAudioSession.sharedInstance().setActive(true)
        #endif

        let input = engine.inputNode
        // Use the hardware's native format for the tap
        let format = input.outputFormat(forBus: 0)

        let (stream, cont) = AsyncStream<[Float]>.makeStream()
        continuation = cont

        input.installTap(onBus: 0, bufferSize: 4096, format: format) { [weak self] buffer, _ in
            // ⚠️ AUDIO THREAD — see constraints below
            guard let pcm = buffer.floatChannelData?[0] else { return }
            let samples = Array(UnsafeBufferPointer(start: pcm, count: Int(buffer.frameLength)))
            self?.continuation?.yield(samples)   // non-blocking enqueue
        }

        engine.prepare()
        try engine.start()
        return stream
    }

    func stop() {
        engine.inputNode.removeTap(onBus: 0)
        engine.stop()
        continuation?.finish()
        continuation = nil
        #if os(iOS)
        try? AVAudioSession.sharedInstance().setActive(false)
        #endif
    }
}
```

## Audio Thread Constraints — CRITICAL

The tap callback runs on a **real-time audio thread** managed by CoreAudio. Violating these rules causes glitches, dropouts, or crashes:

| Forbidden | Why |
|-----------|-----|
| Memory allocation (`Array(...)`, `[Float]()`) | May block on allocator lock |
| Swift class instantiation | Hits the runtime allocator |
| `DispatchQueue.async { }` | Can allocate internally |
| Locks / `os_unfair_lock_lock` if contested | Priority inversion |
| File I/O | Blocks on filesystem |
| Objective-C message sends | Can allocate |
| `try` / `throw` | Swift error handling allocates |

**Safe in tap callbacks:** ring buffer writes (lock-free), `continuation.yield` (lock-free enqueue), raw pointer arithmetic, `UnsafeBufferPointer` reads, `AudioBufferList` access.

The pattern above using `AsyncStream.Continuation.yield` is safe because it uses a lock-free queue internally.

## Format Matching

Format mismatches between tap and downstream processing are the #1 source of `AVAudioEngine` crashes.

```swift
// ✅ Always tap at the node's native output format
let format = input.outputFormat(forBus: 0)
input.installTap(onBus: 0, bufferSize: 4096, format: format) { … }

// If your DSP expects a different sample rate, use AVAudioConverter
let targetFormat = AVAudioFormat(standardFormatWithSampleRate: 44100, channels: 1)!
let converter = AVAudioConverter(from: format, to: targetFormat)!
```

## AVAudioPCMBuffer Access

```swift
// Float32 samples (most common)
buffer.floatChannelData?[0]    // channel 0 pointer — Float32

// Int16 samples
buffer.int16ChannelData?[0]

// Frame count
buffer.frameLength             // frames actually filled
buffer.frameCapacity           // max frames the buffer can hold

// Build a Swift array (do this OFF the audio thread)
let samples = Array(UnsafeBufferPointer(start: buffer.floatChannelData![0],
                                        count: Int(buffer.frameLength)))
```

## iOS Permission Flow

```swift
// Swift 6 / async style
let granted = await AVAudioApplication.requestRecordPermission()
guard granted else { throw CaptureError.permissionDenied }
```

Add `NSMicrophoneUsageDescription` to `Info.plist` or the app will crash on first request.

## Engine Restart After Interruption (iOS)

Audio sessions are interrupted by phone calls, Siri, etc.

```swift
NotificationCenter.default.addObserver(
    forName: AVAudioSession.interruptionNotification,
    object: nil, queue: nil) { [weak self] note in
        guard let type = note.userInfo?[AVAudioSessionInterruptionTypeKey] as? UInt,
              let interruptionType = AVAudioSession.InterruptionType(rawValue: type) else { return }
        switch interruptionType {
        case .began: self?.engine.pause()
        case .ended:
            try? self?.engine.start()   // re-arm after interruption ends
        @unknown default: break
        }
}
```

## Common Mistakes

| Mistake | Fix |
|---------|-----|
| Tapping with a format different from `outputFormat(forBus:)` | Always query the node's actual format first |
| Allocating inside the tap callback | Move allocation to setup; use pre-allocated ring buffer |
| Not calling `removeTap` before `stop()` | Tap callback can fire after engine stops — dangling continuation |
| Forgetting `engine.prepare()` before `start()` | Engine may fail silently or crash |
| Using `AVAudioSession` on macOS | Guarded with `#if os(iOS)` |
| Re-installing tap without removing old one | Engine throws "already has a tap" exception |
