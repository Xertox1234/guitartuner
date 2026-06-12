---
name: metal-render-loop
description: Use when writing or debugging Metal GPU rendering code — MTKView setup, command buffer lifecycle, vertex/fragment shaders, 120fps ProMotion loops, MTLBuffer management, or synchronization between CPU and GPU draw calls.
---

# Metal Render Loop

## Architecture

```
MTKView (drawable surface)
  └── MTKViewDelegate.draw(in:)       ← called every frame by display link
        ├── commandQueue.makeCommandBuffer()
        ├── renderPassDescriptor  ← from view.currentRenderPassDescriptor
        ├── commandBuffer.makeRenderCommandEncoder(descriptor:)
        │     ├── setVertexBytes / setVertexBuffer
        │     ├── setFragmentBytes / setFragmentTexture
        │     └── drawPrimitives(type:vertexStart:vertexCount:)
        ├── encoder.endEncoding()
        ├── commandBuffer.present(view.currentDrawable!)
        └── commandBuffer.commit()
```

## Setup

```swift
class AuroraRenderer: NSObject, MTKViewDelegate {
    let device: MTLDevice
    let commandQueue: MTLCommandQueue
    var pipelineState: MTLRenderPipelineState!

    init(view: MTKView) {
        device = MTLCreateSystemDefaultDevice()!
        commandQueue = device.makeCommandQueue()!
        super.init()

        // 120 fps on ProMotion displays
        view.device = device
        view.preferredFramesPerSecond = 120
        view.isPaused = false
        view.enableSetNeedsDisplay = false
        view.delegate = self

        buildPipeline(view: view)
    }

    func buildPipeline(view: MTKView) {
        let lib = device.makeDefaultLibrary()!
        let desc = MTLRenderPipelineDescriptor()
        desc.vertexFunction = lib.makeFunction(name: "vertexShader")
        desc.fragmentFunction = lib.makeFunction(name: "fragmentShader")
        desc.colorAttachments[0].pixelFormat = view.colorPixelFormat
        // Enable alpha blending if needed:
        desc.colorAttachments[0].isBlendingEnabled = true
        desc.colorAttachments[0].sourceRGBBlendFactor = .sourceAlpha
        desc.colorAttachments[0].destinationRGBBlendFactor = .oneMinusSourceAlpha
        pipelineState = try! device.makeRenderPipelineState(descriptor: desc)
    }

    func draw(in view: MTKView) {
        guard let rpd = view.currentRenderPassDescriptor,
              let drawable = view.currentDrawable,
              let buf = commandQueue.makeCommandBuffer(),
              let enc = buf.makeRenderCommandEncoder(descriptor: rpd) else { return }

        enc.setRenderPipelineState(pipelineState)
        // ... set buffers, draw calls ...
        enc.endEncoding()
        buf.present(drawable)
        buf.commit()
    }

    func mtkView(_ view: MTKView, drawableSizeWillChange size: CGSize) { }
}
```

## Metal Shading Language (MSL) Basics

MSL is C++17 (Metal 4+) / C++14 (prior) with GPU-specific restrictions.

**Not supported:** `double`, `long long`, `new`/`delete`, exceptions, `virtual`, RTTI, `goto`

**Address spaces:** `device` (GPU-readable buffer), `constant` (read-only uniform), `threadgroup` (shared within group), `thread` (per-thread)

```metal
#include <metal_stdlib>
using namespace metal;

struct VertexIn {
    float2 position [[attribute(0)]];
    float2 uv       [[attribute(1)]];
};

struct VertexOut {
    float4 position [[position]];
    float2 uv;
};

// Uniform block passed per-frame
struct Uniforms {
    float phase;    // strobe cycle 0…1
    float2 size;    // view size in points
};

[[vertex]] VertexOut vertexShader(
    VertexIn in [[stage_in]],
    constant Uniforms& u [[buffer(1)]])
{
    VertexOut out;
    out.position = float4(in.position, 0, 1);
    out.uv = in.uv;
    return out;
}

[[fragment]] float4 fragmentShader(
    VertexOut in [[stage_in]],
    constant Uniforms& u [[buffer(1)]])
{
    // Example: phase-driven brightness
    float brightness = fract(in.uv.x + u.phase);
    return float4(brightness, brightness, brightness, 1.0);
}
```

## Passing Per-Frame Data

**Small uniforms (<= 4 KB) — use setVertexBytes:**
```swift
var uniforms = Uniforms(phase: Float(strobePhase), size: SIMD2(w, h))
enc.setVertexBytes(&uniforms, length: MemoryLayout<Uniforms>.stride, index: 1)
enc.setFragmentBytes(&uniforms, length: MemoryLayout<Uniforms>.stride, index: 1)
```

**Larger or streaming data — use MTLBuffer:**
```swift
let buf = device.makeBuffer(bytes: vertices,
                            length: vertices.count * MemoryLayout<VertexIn>.stride,
                            options: .storageModeShared)
enc.setVertexBuffer(buf, offset: 0, index: 0)
```

## CPU–GPU Synchronization

The GPU runs frames behind the CPU. Use a semaphore to prevent overwriting in-flight buffers.

```swift
let inflightSemaphore = DispatchSemaphore(value: 3) // triple-buffer

func draw(in view: MTKView) {
    inflightSemaphore.wait()
    // ... build frame ...
    commandBuffer.addCompletedHandler { [weak self] _ in
        self?.inflightSemaphore.signal()
    }
    commandBuffer.commit()
}
```

## Common Mistakes

| Mistake | Fix |
|---------|-----|
| Calling `draw(in:)` on wrong thread | MTKView calls delegate on a dedicated render thread — never call manually |
| Forgetting `endEncoding()` | GPU will hang waiting for encoder to close |
| Using `double` in MSL | Use `float`; Metal doesn't support `double` |
| Mutating a buffer while GPU reads it | Triple-buffer with semaphore |
| `view.currentRenderPassDescriptor` is nil | Guard and skip frame — drawable may be temporarily unavailable |
| `preferredFramesPerSecond = 120` ignored | Device must support ProMotion; falls back silently on older hardware |

## Debugging

- **Xcode GPU Frame Capture:** Product → Profile → Metal → capture a frame for draw call inspection
- **Metal Validation Layer:** enabled automatically in Debug scheme; surfaces encoder misuse
- `MTLCaptureManager` for programmatic capture during a specific frame
