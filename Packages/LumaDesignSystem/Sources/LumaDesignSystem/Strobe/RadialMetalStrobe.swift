import SwiftUI

/// **Metal hero path for the Radial strobe.** The production renderer for the
/// Radial phase ring: the same rotating marks + convergence ring + lock bloom
/// as `RadialStrobe`, but evaluated per-pixel on the GPU from a `StrobeInput`.
/// A drop-in peer behind the same contract — `StrobeField` swaps it in when
/// `useMetalRenderer` is true and `style == .radial`.
///
/// GPU path can't run in CI (no device) — CI only compiles it. Shader built at
/// runtime via `makeLibrary(source:)`. Validate on-device via StrobeLab fps readout.
public struct RadialMetalStrobe: View {
    var input: StrobeInput
    var animated: Bool
    var phaseScroll: Bool

    @Environment(\.colorScheme) private var scheme
    @Environment(\.lumaPalette) private var palette

    public init(input: StrobeInput, animated: Bool = true, phaseScroll: Bool = false) {
        self.input = input
        self.animated = animated
        self.phaseScroll = phaseScroll
    }

    public var body: some View {
        #if canImport(MetalKit)
        RadialMetalStrobeView(input: input, animated: animated, phaseScroll: phaseScroll,
                              scheme: scheme, palette: palette)
            .accessibilityHidden(true)
        #else
        RadialStrobe(input: input, animated: animated, phaseScroll: phaseScroll)
            .accessibilityHidden(true)
        #endif
    }
}

#if canImport(MetalKit)
import MetalKit
import QuartzCore

#if canImport(UIKit)
private typealias RadialMetalRepresentable = UIViewRepresentable
#elseif canImport(AppKit)
private typealias RadialMetalRepresentable = NSViewRepresentable
#endif

/// SwiftUI ↔ `MTKView` bridge. `RadialStrobeRenderer` is the coordinator and
/// self-drives the view's display link; SwiftUI just pushes the latest `StrobeInput`.
struct RadialMetalStrobeView: RadialMetalRepresentable {
    var input: StrobeInput
    var animated: Bool
    var phaseScroll: Bool
    var scheme: ColorScheme
    var palette: LumaPalette

    func makeCoordinator() -> RadialStrobeRenderer? { RadialStrobeRenderer.make(scheme: scheme) }

    private func makeView(_ renderer: RadialStrobeRenderer?) -> MTKView {
        let view = MTKView()
        view.preferredFramesPerSecond = 120
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

    private func sync(_ view: MTKView, _ renderer: RadialStrobeRenderer?) {
        view.isPaused = !animated
        guard let renderer else { return }
        renderer.input = input
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

/// CPU-side uniforms, laid out to match the Metal `RadialUniforms` struct.
/// Four `float4` colours, then `float2` resolution, then scalars.
private struct RadialUniforms {
    var colMark: SIMD4<Float>
    var colTune: SIMD4<Float>
    var colBg: SIMD4<Float>
    var colInk: SIMD4<Float>
    var resolution: SIMD2<Float>
    var angle: Float
    var R: Float
    var r0: Float
    var r1: Float
    var markHalfW: Float
    var trackHalfW: Float
    var lock: Float
    var prox: Float
    var breath: Float
    var dim: Float
    var markCount: Float
}

/// Metal pipeline for the Radial hero. Owns device/queue/pipeline, integrates
/// the rotation angle + eased lock, and encodes one fullscreen pass per frame.
/// Built via `make(scheme:)`, which fails closed if Metal is unavailable.
final class RadialStrobeRenderer: NSObject, MTKViewDelegate {
    let device: MTLDevice
    private let queue: MTLCommandQueue
    private let pipeline: MTLRenderPipelineState
    private let frameSemaphore = DispatchSemaphore(value: 3)

    var input = StrobeInput()
    var animated = true
    var phaseScroll = false
    var palette: LumaPalette = .aurora
    private var scheme: ColorScheme

    // Integrated clock (mirrors RadialClock).
    private var angle: Double = 0
    private var lockEase: Double = 0
    private var lastTime: Double = 0
    private var lastPhase: Double = -1
    private var phaseChangeTime: Double = 0
    private var rotVel: Double = 0

    private init(device: MTLDevice, queue: MTLCommandQueue,
                 pipeline: MTLRenderPipelineState, scheme: ColorScheme) {
        self.device = device
        self.queue = queue
        self.pipeline = pipeline
        self.scheme = scheme
        super.init()
    }

    static func make(scheme: ColorScheme) -> RadialStrobeRenderer? {
        guard let device = MTLCreateSystemDefaultDevice(),
              let queue = device.makeCommandQueue() else { return nil }
        do {
            let library = try device.makeLibrary(source: shaderSource, options: nil)
            guard let vfn = library.makeFunction(name: "radial_vertex"),
                  let ffn = library.makeFunction(name: "radial_fragment") else { return nil }
            let desc = MTLRenderPipelineDescriptor()
            desc.vertexFunction = vfn
            desc.fragmentFunction = ffn
            desc.colorAttachments[0].pixelFormat = .bgra8Unorm
            let pipeline = try device.makeRenderPipelineState(descriptor: desc)
            return RadialStrobeRenderer(device: device, queue: queue, pipeline: pipeline, scheme: scheme)
        } catch {
            return nil
        }
    }

    func configure(_ view: MTKView) {
        view.colorPixelFormat = .bgra8Unorm
        let bg = StrobePalette.resolve(scheme, palette: palette).bg
        view.clearColor = MTLClearColor(red: bg.r, green: bg.g, blue: bg.b, alpha: 1)
    }

    func update(scheme: ColorScheme, view: MTKView) {
        guard scheme != self.scheme else { return }
        self.scheme = scheme
        configure(view)
    }

    func mtkView(_ view: MTKView, drawableSizeWillChange size: CGSize) {}

    func draw(in view: MTKView) {
        frameSemaphore.wait()
        guard let drawable = view.currentDrawable,
              let pass = view.currentRenderPassDescriptor,
              let cmd = queue.makeCommandBuffer(),
              let enc = cmd.makeRenderCommandEncoder(descriptor: pass) else {
            frameSemaphore.signal()
            return
        }

        var u = makeUniforms(size: view.drawableSize)
        enc.setRenderPipelineState(pipeline)
        enc.setFragmentBytes(&u, length: MemoryLayout<RadialUniforms>.stride, index: 0)
        enc.drawPrimitives(type: .triangle, vertexStart: 0, vertexCount: 3)
        enc.endEncoding()
        cmd.present(drawable)
        cmd.addCompletedHandler { [frameSemaphore] _ in frameSemaphore.signal() }
        cmd.commit()
    }

    private func makeUniforms(size: CGSize) -> RadialUniforms {
        let pal = StrobePalette.resolve(scheme, palette: palette)
        let now = CACurrentMediaTime()
        var dt = 0.0
        if lastTime != 0 { dt = min(0.05, now - lastTime) }
        lastTime = now

        let err = Double(input.cents)
        let inLock = input.locked
        let target = inLock ? 1.0 : 0.0
        lockEase += (target - lockEase) * min(1.0, dt * 6 + (animated ? 0.0 : 1.0))
        let lock = lockEase
        let prox = StrobeMath.proximity(cents: err)
        var photosensitivityDim = 1.0   // WCAG 2.3.1 guard (folded into U.dim below)

        if phaseScroll {
            let phase = Double(input.phase)
            if lastPhase < 0 { lastPhase = phase; phaseChangeTime = now }
            if phase != lastPhase {
                let d = StrobeMath.wrappedDelta(lastPhase, phase)
                let elapsed = now - phaseChangeTime
                if elapsed > 1e-4 { rotVel = d / elapsed }
                lastPhase = phase
                phaseChangeTime = now
            } else if now - phaseChangeTime > 0.25 {
                rotVel = 0
            }
            // WCAG 2.3.1 (C-4b, Lever C): cap rotation speed (aesthetic) + danger-
            // band dim. `effectiveRate` eases to 0 at lock → photosensitivityDim → 1,
            // so the bloom (also × U.dim in the shader) stays byte-identical.
            let effectiveRate = StrobeMath.clampedStrobeRate(rotVel) * (1 - lock)
            photosensitivityDim = StrobeMath.photosensitivityBrightness(rateHz: effectiveRate, ribbonCount: 36)
            if animated { angle += effectiveRate * 2 * .pi * dt }
        } else if animated {
            angle += StrobeMath.ringSpeed(cents: err, lock: lock) * dt
        }
        // Wrap to [0, 2π) to keep Float precision as angle accumulates.
        let twoPi = 2 * Double.pi
        angle -= floor(angle / twoPi) * twoPi

        let breath = input.isIdle ? 0.55 + 0.45 * sin(now * 1.4) : 1.0
        // Match Canvas RadialStrobe: marks multiplied by (light ? 0.6 : 1).
        let dim = (scheme == .light ? 0.6 : 1.0) * photosensitivityDim

        // Geometry in drawable-pixel space (matches Canvas coordinate system).
        let w = Float(size.width)
        let h = Float(max(size.height, 1))
        let R = 0.40 * min(w, h)
        let markLen = R * 0.20
        let colMark = StrobeShaderColors.main(cents: err, prox: prox, lock: lock, pal: pal)

        return RadialUniforms(
            colMark: colMark.simd4,
            colTune: pal.tune.simd4,
            colBg: pal.bg.simd4,
            colInk: pal.ink.simd4,
            resolution: SIMD2<Float>(w, h),
            angle: Float(angle),
            R: R,
            r0: R - markLen * 0.5,
            r1: R + markLen * 0.5,
            markHalfW: max(2.5, R * 0.045) * 0.5,
            trackHalfW: max(8, R * 0.13) * 0.5,
            lock: Float(lock),
            prox: Float(prox),
            breath: Float(breath),
            dim: Float(dim),
            markCount: 36
        )
    }

    /// Compiled at runtime — keeps Metal out of the SwiftPM build graph (CI compiles
    /// Swift; GPU pipeline is built on-device). Reproduces `RadialStrobe`'s rotating
    /// spoke marks + convergence ring + lock bloom, all evaluated per-pixel.
    ///
    /// Coordinates: pixel-space centered at (0,0), matching the Canvas renderer.
    /// p.x ∈ [-w/2, w/2], p.y ∈ [-h/2, h/2] via `(uv - 0.5) * resolution`.
    static let shaderSource = """
    #include <metal_stdlib>
    using namespace metal;

    struct RadialUniforms {
        float4 colMark;
        float4 colTune;
        float4 colBg;
        float4 colInk;
        float2 resolution;
        float angle;
        float R;
        float r0;
        float r1;
        float markHalfW;
        float trackHalfW;
        float lock;
        float prox;
        float breath;
        float dim;
        float markCount;
    };

    struct VSOut {
        float4 position [[position]];
        float2 uv;
    };

    vertex VSOut radial_vertex(uint vid [[vertex_id]]) {
        float2 verts[3] = { float2(-1.0, -1.0), float2(3.0, -1.0), float2(-1.0, 3.0) };
        VSOut out;
        float2 p = verts[vid];
        out.position = float4(p, 0.0, 1.0);
        out.uv = p * 0.5 + 0.5;
        return out;
    }

    fragment float4 radial_fragment(VSOut in [[stage_in]],
                                    constant RadialUniforms& U [[buffer(0)]]) {
        // Pixel-space coordinates centered at (0,0) — matches Canvas origin.
        float2 p = (in.uv - 0.5) * U.resolution;
        float r = length(p);
        float lock = U.lock;
        float prox = U.prox;
        float3 light = float3(0.0);
        int n = int(U.markCount);
        float TWO_PI = 6.28318530718;
        float HALF_PI = 1.57079632679;

        // 1. Phase mark spokes — distance field over 36 line segments.
        for (int i = 0; i < n; i++) {
            float a_i = (float(i) / float(n)) * TWO_PI + U.angle;
            float2 sd = float2(cos(a_i), sin(a_i));

            // Signed projection onto spoke axis; clamped to [r0, r1] extent.
            float t = dot(p, sd);
            float t_clamped = clamp(t, U.r0, U.r1);
            float dist = length(p - t_clamped * sd);
            float coverage = max(0.0, 1.0 - dist / U.markHalfW);

            // Along-spoke gradient: 0.5× at ends, 1.0× at midpoint (matches Canvas).
            float along = (t_clamped - U.r0) / (U.r1 - U.r0);
            float grad = 0.5 + 0.5 * (1.0 - 2.0 * abs(along - 0.5));

            // Brightness envelope: peaks at ring top (a = −π/2).
            float phase = cos(a_i + HALF_PI);
            float env = 0.35 + 0.65 * pow((phase + 1.0) * 0.5, 1.5);
            float alpha = (0.12 + 0.6 * env) * U.breath * (1.0 - lock * 0.35) * U.dim;

            light += U.colMark.rgb * (coverage * grad * alpha);
        }

        // 2. Faint base track (circle outline, opacity 0.05 matches Canvas).
        float ringDist = abs(r - U.R);
        float trackCov = max(0.0, 1.0 - ringDist / U.trackHalfW);
        light += U.colInk.rgb * (trackCov * 0.05);

        // 3. Continuous solid ring as proximity / lock fills in.
        float ringA = max(lock, (prox - 0.4) * 0.6);
        if (ringA > 0.01) {
            float ringHalfW = U.markHalfW * (1.0 + lock);
            float ringCov = max(0.0, 1.0 - ringDist / ringHalfW);
            float3 ringCol = mix(U.colMark.rgb, U.colTune.rgb, lock);
            light += ringCol * (0.5 * ringA * ringCov);
        }

        // 4. Bloom halo at lock (radial gradient — matches Canvas stops).
        if (lock > 0.01) {
            float inner = U.R * 0.2;
            float outer = U.R * 1.5;
            float t = clamp((r - inner) / (outer - inner), 0.0, 1.0);
            // Gradient: 0.10 @ t=0 → 0.22 @ t=0.45 → 0.06 @ t=0.7 → 0 @ t=1
            float bloom;
            if (t < 0.45) {
                bloom = mix(0.10, 0.22, t / 0.45);
            } else if (t < 0.70) {
                bloom = mix(0.22, 0.06, (t - 0.45) / 0.25);
            } else {
                bloom = mix(0.06, 0.00, (t - 0.70) / 0.30);
            }
            light += U.colTune.rgb * (bloom * lock * U.dim);
        }

        float3 outc = U.colBg.rgb + light;
        return float4(min(outc, float3(1.0)), 1.0);
    }
    """
}
#endif
