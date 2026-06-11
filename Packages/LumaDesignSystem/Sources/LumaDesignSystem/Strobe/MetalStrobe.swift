import SwiftUI

/// **Metal hero path (DESIGN §5).** The production renderer for the Aurora strobe:
/// the same scrolling, converging ribbons + mint lock-bloom as `AuroraStrobe`, but
/// evaluated per-pixel on the GPU from a `StrobeInput`. A drop-in peer behind the
/// same contract — `StrobeField` swaps it in when the Metal renderer is enabled,
/// with the Canvas Aurora staying the default.
///
/// The live GPU path can't run in CI (no device) — CI only *compiles* it. The
/// shader is compiled from source at runtime via `makeLibrary(source:)`, so there's
/// no `.metal` build step in the SwiftPM package. Validate on-device (the lab's fps
/// readout is the A/B surface).
public struct MetalStrobe: View {
    var input: StrobeInput
    var idle: Bool
    var animated: Bool
    var phaseScroll: Bool

    @Environment(\.colorScheme) private var scheme
    @Environment(\.lumaPalette) private var palette

    public init(input: StrobeInput, idle: Bool = false, animated: Bool = true, phaseScroll: Bool = false) {
        self.input = input
        self.idle = idle
        self.animated = animated
        self.phaseScroll = phaseScroll
    }

    public var body: some View {
        #if canImport(MetalKit)
        MetalStrobeView(input: input, idle: idle, animated: animated, phaseScroll: phaseScroll, scheme: scheme, palette: palette)
            .accessibilityHidden(true)
        #else
        // No Metal available (non-Apple) — fall back to the Canvas hero.
        AuroraStrobe(input: input, idle: idle, animated: animated, phaseScroll: phaseScroll)
            .accessibilityHidden(true)
        #endif
    }
}

#if canImport(MetalKit)
import MetalKit
import QuartzCore

#if canImport(UIKit)
private typealias StrobeMetalRepresentable = UIViewRepresentable
#elseif canImport(AppKit)
private typealias StrobeMetalRepresentable = NSViewRepresentable
#endif

/// SwiftUI ↔ `MTKView` bridge. `StrobeRenderer` is the coordinator and self-drives
/// the view's display link; SwiftUI just pushes the latest `StrobeInput` on update.
struct MetalStrobeView: StrobeMetalRepresentable {
    var input: StrobeInput
    var idle: Bool
    var animated: Bool
    var phaseScroll: Bool
    var scheme: ColorScheme
    var palette: LumaPalette

    func makeCoordinator() -> StrobeRenderer? { StrobeRenderer.make(scheme: scheme) }

    private func makeView(_ renderer: StrobeRenderer?) -> MTKView {
        let view = MTKView()
        view.preferredFramesPerSecond = 120          // ProMotion caps to the panel
        view.enableSetNeedsDisplay = false
        view.isPaused = !animated
        view.framebufferOnly = true
        if let renderer {
            view.device = renderer.device
            view.delegate = renderer
            renderer.configure(view)
        }
        return view
    }

    private func sync(_ view: MTKView, _ renderer: StrobeRenderer?) {
        view.isPaused = !animated
        guard let renderer else { return }
        renderer.input = input
        renderer.idle = idle
        renderer.animated = animated
        renderer.phaseScroll = phaseScroll
        renderer.palette = palette
        renderer.update(scheme: scheme, view: view)
    }

    #if canImport(UIKit)
    func makeUIView(context: Context) -> MTKView { makeView(context.coordinator) }
    func updateUIView(_ uiView: MTKView, context: Context) { sync(uiView, context.coordinator) }
    #elseif canImport(AppKit)
    func makeNSView(context: Context) -> MTKView { makeView(context.coordinator) }
    func updateNSView(_ nsView: MTKView, context: Context) { sync(nsView, context.coordinator) }
    #endif
}

/// CPU-side uniforms, laid out to match the Metal `StrobeUniforms` struct: four
/// `float4` colours, then `float2` resolution, then scalars (16-byte aligned).
private struct StrobeUniforms {
    var colMain: SIMD4<Float>
    var colColumn: SIMD4<Float>
    var colTune: SIMD4<Float>
    var colBg: SIMD4<Float>
    var resolution: SIMD2<Float>
    var scroll: Float
    var spread: Float
    var lock: Float
    var prox: Float
    var breath: Float
    var dim: Float
    var ribbonCount: Float
}

/// The Metal pipeline for the Aurora hero. Owns the device/queue/pipeline, mirrors
/// `AuroraClock`'s integrated scroll + eased lock, and encodes one fullscreen pass
/// per frame. Built via `make(scheme:)`, which fails closed if Metal is unavailable
/// (CI never reaches here — the view isn't instantiated during a build).
final class StrobeRenderer: NSObject, MTKViewDelegate {
    let device: MTLDevice
    private let queue: MTLCommandQueue
    private let pipeline: MTLRenderPipelineState

    // Pushed from SwiftUI each update.
    var input = StrobeInput()
    var idle = false
    var animated = true
    var phaseScroll = false
    var palette: LumaPalette = .aurora
    private var scheme: ColorScheme

    // Integrated clock (mirrors AuroraClock).
    private var scroll: Double = 0
    private var lockEase: Double = 0
    private var lastTime: Double = 0
    private var lastPhase: Double = -1
    private var phaseChangeTime: Double = 0
    private var scrollVel: Double = 0

    private init(device: MTLDevice, queue: MTLCommandQueue, pipeline: MTLRenderPipelineState, scheme: ColorScheme) {
        self.device = device
        self.queue = queue
        self.pipeline = pipeline
        self.scheme = scheme
        super.init()
    }

    /// Build the device/queue/pipeline up front; return nil (→ blank view) if Metal
    /// is unavailable or the shader fails to compile. The designated init assigns
    /// every stored property unconditionally, so there's no partially-initialized
    /// failable path.
    static func make(scheme: ColorScheme) -> StrobeRenderer? {
        guard let device = MTLCreateSystemDefaultDevice(),
              let queue = device.makeCommandQueue() else { return nil }
        do {
            let library = try device.makeLibrary(source: shaderSource, options: nil)
            guard let vfn = library.makeFunction(name: "strobe_vertex"),
                  let ffn = library.makeFunction(name: "strobe_fragment") else { return nil }
            let desc = MTLRenderPipelineDescriptor()
            desc.vertexFunction = vfn
            desc.fragmentFunction = ffn
            desc.colorAttachments[0].pixelFormat = .bgra8Unorm
            let pipeline = try device.makeRenderPipelineState(descriptor: desc)
            return StrobeRenderer(device: device, queue: queue, pipeline: pipeline, scheme: scheme)
        } catch {
            return nil
        }
    }

    /// Match the drawable format + clear to the palette background.
    func configure(_ view: MTKView) {
        view.colorPixelFormat = .bgra8Unorm
        let bg = StrobePalette.resolve(scheme).bg
        view.clearColor = MTLClearColor(red: bg.r, green: bg.g, blue: bg.b, alpha: 1)
    }

    func update(scheme: ColorScheme, view: MTKView) {
        guard scheme != self.scheme else { return }
        self.scheme = scheme
        configure(view)
    }

    func mtkView(_ view: MTKView, drawableSizeWillChange size: CGSize) {}

    func draw(in view: MTKView) {
        guard let drawable = view.currentDrawable,
              let pass = view.currentRenderPassDescriptor,
              let cmd = queue.makeCommandBuffer(),
              let enc = cmd.makeRenderCommandEncoder(descriptor: pass) else { return }

        var u = makeUniforms(size: view.drawableSize)
        enc.setRenderPipelineState(pipeline)
        enc.setFragmentBytes(&u, length: MemoryLayout<StrobeUniforms>.stride, index: 0)
        enc.drawPrimitives(type: .triangle, vertexStart: 0, vertexCount: 3)
        enc.endEncoding()
        cmd.present(drawable)
        cmd.commit()
    }

    private func makeUniforms(size: CGSize) -> StrobeUniforms {
        let pal = StrobePalette.resolve(scheme, palette: palette)
        let now = CACurrentMediaTime()
        var dt = 0.0
        if lastTime != 0 { dt = min(0.05, now - lastTime) }
        lastTime = now

        let err = input.cents
        let inLock = input.locked || abs(err) < LumaMusic.lockCents
        let target = inLock ? 1.0 : 0.0
        lockEase += (target - lockEase) * min(1.0, dt * 6 + (animated ? 0.0 : 1.0))
        let lock = lockEase
        let prox = StrobeMath.proximity(cents: err)

        if phaseScroll {
            // Engine-driven true strobe: estimate scroll velocity from the live phase
            // advance, eased to zero at lock (mirrors AuroraStrobe).
            if lastPhase < 0 { lastPhase = input.phase; phaseChangeTime = now }
            if input.phase != lastPhase {
                let d = AuroraStrobe.wrappedDelta(lastPhase, input.phase)
                let elapsed = now - phaseChangeTime
                if elapsed > 1e-4 { scrollVel = d / elapsed }
                lastPhase = input.phase
                phaseChangeTime = now
            } else if now - phaseChangeTime > 0.25 {
                scrollVel = 0                                   // stale (silence)
            }
            if animated { scroll += scrollVel * dt * (1 - lock) }
        } else if animated {
            scroll += StrobeMath.scrollSpeed(cents: err, lock: lock) * dt
        }

        let breath = idle ? 0.6 + 0.4 * sin(now * 1.4) : 1.0
        let dim = scheme == .light ? 0.5 : 1.0
        let main = StrobeShaderColors.main(cents: err, prox: prox, lock: lock, pal: pal)
        let column = StrobeShaderColors.column(main: main, lock: lock, pal: pal)

        return StrobeUniforms(
            colMain: main.simd4,
            colColumn: column.simd4,
            colTune: pal.tune.simd4,
            colBg: pal.bg.simd4,
            resolution: SIMD2<Float>(Float(size.width), Float(max(size.height, 1))),
            scroll: Float(scroll - floor(scroll)),              // pre-wrap → keep Float precision
            spread: Float(StrobeMath.spread(prox: prox, lock: lock)),
            lock: Float(lock),
            prox: Float(prox),
            breath: Float(breath),
            dim: Float(dim),
            ribbonCount: 13
        )
    }

    /// Compiled at runtime — keeps Metal out of the SwiftPM build graph (CI compiles
    /// the Swift; the GPU pipeline is built on-device). Reproduces `AuroraStrobe`'s
    /// ribbons + central column + lock bloom, additive over the palette background.
    static let shaderSource = """
    #include <metal_stdlib>
    using namespace metal;

    struct StrobeUniforms {
        float4 colMain;
        float4 colColumn;
        float4 colTune;
        float4 colBg;
        float2 resolution;
        float scroll;
        float spread;
        float lock;
        float prox;
        float breath;
        float dim;
        float ribbonCount;
    };

    struct VSOut {
        float4 position [[position]];
        float2 uv;
    };

    vertex VSOut strobe_vertex(uint vid [[vertex_id]]) {
        float2 verts[3] = { float2(-1.0, -1.0), float2(3.0, -1.0), float2(-1.0, 3.0) };
        VSOut out;
        float2 p = verts[vid];
        out.position = float4(p, 0.0, 1.0);
        out.uv = p * 0.5 + 0.5;
        return out;
    }

    // Shortest distance between two points on a wrapped 0..1 axis.
    static inline float wrapDist(float a, float b) {
        float d = fabs(a - b);
        return min(d, 1.0 - d);
    }

    fragment float4 strobe_fragment(VSOut in [[stage_in]],
                                    constant StrobeUniforms& U [[buffer(0)]]) {
        float u = in.uv.x;
        float lock = U.lock;
        float prox = U.prox;
        float breath = U.breath;
        int n = int(U.ribbonCount);

        float3 light = float3(0.0);

        // Scrolling, converging ribbons.
        for (int i = 0; i < n; i++) {
            float f = (n == 1) ? 0.5 : float(i) / float(n - 1);
            float centered = (f - 0.5) * 2.0;
            float pos = 0.5 + centered * U.spread + U.scroll;
            pos -= floor(pos);
            float dxc = (pos - 0.5) / 0.34;
            float env = exp(-dxc * dxc);
            float a = (0.10 + 0.5 * env) * breath * (1.0 - lock * 0.55);
            float bw = 0.05 * (0.7 + env * 1.1);
            float band = max(0.0, 1.0 - wrapDist(u, pos) / bw);
            light += U.colMain.rgb * (a * band);
        }

        // Central column — grows as we converge / lock.
        float colA = (0.18 + 0.55 * max(prox, lock)) * breath;
        float colW = (0.018 + 0.05 * max(prox, lock)) * 3.0;
        float bandCol = max(0.0, 1.0 - fabs(u - 0.5) / colW);
        light += U.colColumn.rgb * (colA * bandCol);

        // Bloom halo at lock (aspect-correct).
        if (lock > 0.01) {
            float aspect = U.resolution.x / U.resolution.y;
            float2 d = (in.uv - 0.5) * float2(aspect, 1.0);
            float halo = max(0.0, 1.0 - length(d) / 0.55);
            light += U.colTune.rgb * (0.32 * lock * halo);
        }

        float3 outc = U.colBg.rgb + light * U.dim;
        return float4(min(outc, float3(1.0)), 1.0);
    }
    """
}
#endif
