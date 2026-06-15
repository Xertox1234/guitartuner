---
title: "Metal triple-buffer semaphore: setup, early-exit, and dealloc safety"
track: knowledge
category: best-practices
tags: [strobe]
module: LumaDesignSystem
applies_to: ["Packages/LumaDesignSystem/Sources/LumaDesignSystem/Strobe/MetalStrobe.swift"]
created: 2026-06-15
---

## When this applies

Any `MTKViewDelegate.draw(in:)` implementation that triple-buffers uniform data to keep
the CPU and GPU pipelining independently.

## The pattern

**1. Initialize to 3, not 1.**  
`DispatchSemaphore(value: 3)` — one slot per in-flight frame buffer. The CPU is allowed
to be up to 3 frames ahead of the GPU. Using `value: 1` serializes CPU and GPU, halving
throughput and causing visible jank at 120 fps.

**2. Signal on every early-exit path.**  
`wait()` is the first line of `draw(in:)`. Every return after that — guard failures,
`nil` drawable, `nil` command buffer — must call `signal()` before returning or the
semaphore permanently loses a slot, eventually deadlocking the render loop.

```swift
func draw(in view: MTKView) {
    frameSemaphore.wait()
    guard let drawable = view.currentDrawable else {
        frameSemaphore.signal()   // ← REQUIRED on every early return
        return
    }
    // ...
}
```

**3. Register `addCompletedHandler` BEFORE `commit()`.**  
The GPU completion handler must be attached before `commit()`. If the GPU is idle and the
command buffer completes synchronously during `commit()`, a handler registered after the
call is never invoked — the semaphore slot is permanently lost.

```swift
// Correct order:
cmd.present(drawable)
cmd.addCompletedHandler { [frameSemaphore] _ in   // ← before commit()
    frameSemaphore.signal()
}
cmd.commit()   // ← last
```

**4. Capture semaphore by value in the completion handler.**  
Use `[frameSemaphore]` (not `[weak self]`). If the `StrobeRenderer` is deallocated while
a frame is in flight, `[weak self]` resolves to `nil` inside the handler — the signal is
never sent, the next `wait()` deadlocks. Capturing the semaphore directly is safe because
`DispatchSemaphore` is a reference type and the extra retain is intentional.

## Why

Metal's triple-buffer pattern overlaps CPU encoding of frame N+1 with GPU execution of
frame N. The semaphore enforces the invariant that no more than 3 frames are simultaneously
in-flight. All four constraints above are required for this to hold — any one violation
produces a latent deadlock or renderer corruption under load.

The ordering race (point 3) is the most non-obvious: it can only trigger when the GPU is
faster than the CPU (e.g., simple scene, Simulator) and the handler is registered between
`commit()` returning and the next `wait()` — a window that exists even on real hardware
under ProMotion at 120 fps.

## Related files

- `Packages/LumaDesignSystem/Sources/LumaDesignSystem/Strobe/MetalStrobe.swift` — `StrobeRenderer.draw(in:)`
