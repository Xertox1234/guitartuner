---
name: swift-concurrency
description: Use when writing or reviewing Swift actors, @MainActor, AsyncStream, Sendable types, Task creation, or structured concurrency — especially when crossing actor isolation boundaries, bridging callback APIs, or seeing "sendable" / "actor-isolated" compiler errors.
---

# Swift Concurrency

## Core Model

Swift concurrency prevents data races at compile time. Every mutable value belongs to exactly one isolation domain. Crossing domains requires `await`.

Three isolation domains:
- **Actor instance** — `actor Foo { }` protects all stored properties
- **Global actor** — `@MainActor` (the UI domain), `@AudioActor` (custom)
- **Unstructured / non-isolated** — no implicit isolation; only `Sendable` values cross

## Actors

```swift
// actor protects all stored properties — no locks needed
public actor TunerEngine {
    private var pipeline = PitchPipeline()

    // Synchronous access inside actor — fine
    func process(_ samples: [Float]) -> PitchReading {
        pipeline.push(samples)
    }

    // Opt out for pure computation that doesn't touch state
    nonisolated func noteName(for freq: Float) -> String { … }
}

// Caller must await to cross the isolation boundary
let reading = await engine.process(buffer)
```

## @MainActor

Mark any class that owns UI state `@MainActor`. All stored properties and methods become main-thread-only automatically.

```swift
@MainActor @Observable
class LiveTunerModel {
    var cents: Float = 0          // safe — always on main thread
    var isListening = false

    // Explicitly run a block on main actor from non-isolated context
    Task { @MainActor in
        self.isListening = true
    }
}
```

## AsyncStream — the bridge from callbacks to async

Use `AsyncStream` to turn a push-based source (audio tap, delegate callback) into a consumable sequence.

```swift
// Producer side — create stream + retain continuation
let (stream, continuation) = AsyncStream<PitchReading>.makeStream()

// Feed values from any thread/callback
continuation.yield(reading)

// Signal end of stream
continuation.finish()

// Consumer side — structured, cancellable
for await reading in stream {
    await model.update(reading)
}
```

**Never** resume a continuation more than once. Hold `continuation` in the actor that owns the producer; `finish()` in `deinit` or on task cancellation.

## Sendable

A type that can safely cross actor boundaries must conform to `Sendable`.

| Pattern | How |
|---------|-----|
| Value types (struct, enum) with all-Sendable fields | Implicit conformance |
| Actor | Automatic (actors are `Sendable`) |
| Class with no mutable state | `final class Foo: Sendable` |
| Class with lock-protected mutation | `final class Foo: @unchecked Sendable` + document the lock |
| Closure crossing boundary | Must be `@Sendable` |

`PitchReading` must be `Sendable` because it crosses from `TunerEngine` (actor) to `LiveTunerModel` (@MainActor).

## Bridging Callback APIs

```swift
// One-shot callback → async
func requestPermission() async -> Bool {
    await withCheckedContinuation { continuation in
        AVAudioSession.sharedInstance().requestRecordPermission { granted in
            continuation.resume(returning: granted)
        }
    }
}
```

## Task Lifecycle

```swift
// Unstructured task — fire-and-forget; capture carefully
Task { [weak self] in
    guard let self else { return }
    await self.start()
}

// Structured — result flows back, cancellation propagates
let result = await withTaskGroup(of: PitchReading?.self) { group in
    group.addTask { await analyze(bufferA) }
    group.addTask { await analyze(bufferB) }
    return await group.reduce(into: []) { $0.append($1) }
}

// Cancel a stored task
private var listeningTask: Task<Void, Never>?
listeningTask?.cancel()
```

## deinit pattern

`deinit` is non-isolated. Capture isolated values explicitly.

```swift
actor TunerEngine {
    private let continuation: AsyncStream<PitchReading>.Continuation

    deinit {
        Task { [continuation] in   // capture by value, not self
            continuation.finish()
        }
    }
}
```

## Common Mistakes

| Mistake | Fix |
|---------|-----|
| Accessing actor state from `nonisolated` method | Remove `nonisolated` or use `await` |
| Storing a non-Sendable type in an `@Sendable` closure | Make type Sendable or move it inside the actor |
| Resuming continuation twice | Use a guard/flag; `withCheckedContinuation` traps on double-resume in debug |
| Capturing `self` in `deinit` Task | Capture the specific property by value instead |
| Long-running sync work blocking actor | Use `Task.detached` or move to a background executor |

## Swift 6 Mode

Enable strict concurrency early: add `-strict-concurrency=complete` to Package.swift target flags. Treat warnings as data-race candidates before they become errors.
