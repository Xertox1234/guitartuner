import SwiftUI
import Foundation

/// Mutable per-instance clock — integrated scroll + eased lock + last frame
/// time. A reference type so the `Canvas` closure can advance it without the
/// "modifying state during view update" trap (`TimelineView` drives redraws).
final class AuroraClock {
    var scroll: Double = 0
    var lock: Double = 0
    var last: Double = 0
    // Phase-driven mode (opt-in): track the engine's last strobe phase, when it
    // changed, and the resulting scroll velocity (cycles/sec).
    var lastPhase: Double = -1
    var phaseChangeTime: Double = 0
    var scrollVel: Double = 0
}

/// **Concept A — Aurora ribbons.** Vertical ribbons of light flow laterally:
/// speed = pitch error, direction = sharp(→)/flat(←). Near pitch they converge
/// to one bright central column; at lock the field **freezes and blooms** in the
/// sacred mint. Additive luminosity on the dark field (`source-over` in light).
///
/// Ported from `docs/design_reference/strobe-aurora.jsx`. Driven by a
/// `StrobeInput`; self-animating via `TimelineView`, so it drops straight into a
/// hero field. The eventual Metal hero path (`StrobeRenderer`, DESIGN §5) can
/// replace this while keeping the same input contract.
public struct AuroraStrobe: View {
    var input: StrobeInput
    var idle: Bool
    var animated: Bool
    var ribbonCount: Int
    /// When `true`, lateral scroll is driven by the engine's live `phase`
    /// (`StrobeInput.phase`) at the measured beat velocity — a true strobe — instead
    /// of the cents-derived approximation. Default `false` keeps the simulator path.
    var phaseScroll: Bool

    @Environment(\.colorScheme) private var scheme
    @Environment(\.lumaPalette) private var palette
    @State private var clock = AuroraClock()

    public init(input: StrobeInput, idle: Bool = false, animated: Bool = true, ribbonCount: Int = 13, phaseScroll: Bool = false) {
        self.input = input
        self.idle = idle
        self.animated = animated
        self.ribbonCount = ribbonCount
        self.phaseScroll = phaseScroll
    }

    /// Shortest signed distance between two wrapped 0…1 phases, in (−0.5, 0.5].
    static func wrappedDelta(_ a: Double, _ b: Double) -> Double {
        var d = b - a
        d -= d.rounded()
        return d
    }

    public var body: some View {
        TimelineView(.animation(paused: !animated)) { timeline in
            Canvas { context, size in
                draw(&context, size, time: timeline.date.timeIntervalSinceReferenceDate)
            }
        }
        .accessibilityHidden(true)
    }

    private func draw(_ ctx: inout GraphicsContext, _ size: CGSize, time: Double) {
        let pal = StrobePalette.resolve(scheme, palette: palette)
        let light = scheme == .light
        let w = size.width, h = size.height
        guard w > 1, h > 1 else { return }
        let cx = w / 2
        let err = input.cents
        let sign: Double = err < 0 ? -1 : 1
        let inLock = input.locked

        // dt (clamped like the export clock)
        var dt = 0.0
        if clock.last != 0 { dt = min(0.05, time - clock.last) }
        clock.last = time

        // ease the lock mix 0→1 (snap immediately for non-animated snapshots)
        let target = inLock ? 1.0 : 0.0
        clock.lock += (target - clock.lock) * min(1.0, dt * 6 + (animated ? 0.0 : 1.0))
        let lock = clock.lock

        let prox = StrobeMath.proximity(cents: err)
        if phaseScroll {
            // Engine-driven: estimate scroll velocity from the live phase advance
            // (Δphase over the time between readings), eased to zero at lock.
            if clock.lastPhase < 0 { clock.lastPhase = input.phase; clock.phaseChangeTime = time }
            if input.phase != clock.lastPhase {
                let d = AuroraStrobe.wrappedDelta(clock.lastPhase, input.phase)
                let elapsed = time - clock.phaseChangeTime
                if elapsed > 1e-4 { clock.scrollVel = d / elapsed }
                clock.lastPhase = input.phase
                clock.phaseChangeTime = time
            } else if time - clock.phaseChangeTime > 0.25 {
                clock.scrollVel = 0          // stale (silence) → stop drifting
            }
            if animated { clock.scroll += clock.scrollVel * dt * (1 - lock) }
        } else if animated {
            clock.scroll += StrobeMath.scrollSpeed(cents: err, lock: lock) * dt
        }

        let breath = idle ? 0.6 + 0.4 * sin(time * 1.4) : 1.0

        // colour for the current side, blended toward mint by proximity + lock
        let side = sign < 0 ? mix(pal.flat, pal.flat2, 0.35) : mix(pal.sharp, pal.sharp2, 0.35)
        let col = mix(side, pal.tune, max(prox * 0.7, lock))
        let spread = StrobeMath.spread(prox: prox, lock: lock)

        ctx.blendMode = light ? .normal : .plusLighter

        let ribW = max(3, w * 0.05)
        for i in 0..<ribbonCount {
            let f = ribbonCount == 1 ? 0.5 : Double(i) / Double(ribbonCount - 1)
            let centered = (f - 0.5) * 2
            var pos = 0.5 + centered * spread + clock.scroll
            pos -= floor(pos)
            let x = pos * w
            let env = exp(-pow((x - cx) / (w * 0.34), 2))
            let a = (0.10 + 0.5 * env) * breath * (1 - lock * 0.55) * (light ? 0.5 : 1)
            if a < 0.01 { continue }
            let bw = ribW * (0.7 + env * 1.1)
            fillBand(&ctx, centerX: x, halfWidth: bw, height: h, color: col, alpha: a)
        }

        // central column — grows as we converge / lock
        let colCol = mix(col, pal.tune, lock)
        let colA = (0.18 + 0.55 * max(prox, lock)) * breath * (light ? 0.5 : 1)
        let colW = w * (0.018 + 0.05 * max(prox, lock))
        fillBand(&ctx, centerX: cx, halfWidth: colW * 3, height: h, color: colCol, alpha: colA)

        // bloom halo at lock
        if lock > 0.01 {
            let bScale = light ? 0.55 : 1.0
            let halo = Gradient(stops: [
                .init(color: Color(pal.tune, opacity: 0.32 * lock * bScale), location: 0),
                .init(color: Color(pal.tune, opacity: 0.12 * lock * bScale), location: 0.5),
                .init(color: Color(pal.tune, opacity: 0), location: 1)
            ])
            ctx.fill(
                Path(CGRect(x: 0, y: 0, width: w, height: h)),
                with: .radialGradient(halo, center: CGPoint(x: cx, y: h / 2), startRadius: 0, endRadius: h * 0.55)
            )
        }

        // direction guide: a faint centre baseline (legibility, not colour-only)
        ctx.blendMode = .normal
        var baseline = Path()
        baseline.move(to: CGPoint(x: 0, y: h / 2))
        baseline.addLine(to: CGPoint(x: w, y: h / 2))
        ctx.stroke(baseline, with: .color(Color(pal.ink, opacity: 0.05)), lineWidth: 1)
    }

    /// A full-height band with a soft horizontal falloff (transparent → α → transparent).
    private func fillBand(_ ctx: inout GraphicsContext, centerX x: CGFloat, halfWidth bw: CGFloat, height h: CGFloat, color col: RGB, alpha a: Double) {
        let grad = Gradient(stops: [
            .init(color: Color(col, opacity: 0), location: 0),
            .init(color: Color(col, opacity: a), location: 0.5),
            .init(color: Color(col, opacity: 0), location: 1)
        ])
        ctx.fill(
            Path(CGRect(x: x - bw, y: 0, width: bw * 2, height: h)),
            with: .linearGradient(grad, startPoint: CGPoint(x: x - bw, y: 0), endPoint: CGPoint(x: x + bw, y: 0))
        )
    }
}

#if DEBUG
private struct AuroraDemo: View {
    let cents: Double
    var body: some View {
        AuroraStrobe(input: StrobeInput(cents: cents, locked: abs(cents) < LumaMusic.lockCents))
            .frame(width: 360, height: 420)
            .background(Color.lumaBg)
    }
}

#Preview("Aurora — flat (dark)") { AuroraDemo(cents: -24).preferredColorScheme(.dark) }
#Preview("Aurora — sharp (dark)") { AuroraDemo(cents: 16).preferredColorScheme(.dark) }
#Preview("Aurora — locked (dark)") { AuroraDemo(cents: 0).preferredColorScheme(.dark) }
#Preview("Aurora — flat (light)") { AuroraDemo(cents: -24).preferredColorScheme(.light) }
#endif
