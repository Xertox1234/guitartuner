import SwiftUI
import Foundation

/// Mutable per-instance clock for the Radial ring — integrated rotation angle +
/// eased lock + last frame time, plus the phase-driven velocity estimate. A
/// reference type so the `Canvas` closure can advance it without the "modifying
/// state during view update" trap (`TimelineView` drives redraws). Mirrors
/// `AuroraClock`.
final class RadialClock {
    var angle: Double = 0
    var lock: Double = 0
    var last: Double = 0
    // Phase-driven mode (opt-in): track the engine's last strobe phase, when it
    // changed, and the resulting rotation velocity (cycles/sec).
    var lastPhase: Double = -1
    var phaseChangeTime: Double = 0
    var rotVel: Double = 0
}

/// **Concept B — Radial phase ring.** A glowing ring of phase marks rotates around
/// the note: speed = pitch error, direction = sharp (CW) / flat (CCW). Near pitch a
/// continuous ring fills in; at lock it **freezes and blooms** into the sacred mint
/// halo. Additive luminosity on the dark field (`source-over` in light).
///
/// Ported from `docs/design_reference/strobe-radial.jsx`. The second hero visual
/// (DESIGN §2.2, *ship both, user-selectable*), driven by the same `StrobeInput`
/// contract and self-animating via `TimelineView` — a drop-in peer of `AuroraStrobe`
/// inside `StrobeField`. The eventual Metal hero path (`StrobeRenderer`, DESIGN §5)
/// can replace this while keeping the same input contract.
public struct RadialStrobe: View {
    var input: StrobeInput
    var animated: Bool
    var marks: Int
    /// When `true`, rotation is driven by the engine's live `phase`
    /// (`StrobeInput.phase`) at the measured beat velocity — a true strobe — instead
    /// of the cents-derived approximation. Default `false` keeps the simulator path.
    var phaseScroll: Bool

    @Environment(\.colorScheme) private var scheme
    @Environment(\.lumaPalette) private var palette
    @State private var clock = RadialClock()

    public init(input: StrobeInput, animated: Bool = true, marks: Int = 36, phaseScroll: Bool = false) {
        self.input = input
        self.animated = animated
        self.marks = marks
        self.phaseScroll = phaseScroll
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
        let w = Double(size.width), h = Double(size.height)
        guard w > 1, h > 1 else { return }
        let cx = w / 2, cy = h / 2
        let R = min(w, h) * 0.40
        let err = Double(input.cents)
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

        // advance rotation: engine phase (true strobe) or cents-derived approximation
        if phaseScroll {
            let phase = Double(input.phase)
            if clock.lastPhase < 0 { clock.lastPhase = phase; clock.phaseChangeTime = time }
            if phase != clock.lastPhase {
                let d = AuroraStrobe.wrappedDelta(clock.lastPhase, phase)
                let elapsed = time - clock.phaseChangeTime
                if elapsed > 1e-4 { clock.rotVel = d / elapsed }
                clock.lastPhase = phase
                clock.phaseChangeTime = time
            } else if time - clock.phaseChangeTime > 0.25 {
                clock.rotVel = 0            // stale (silence) → stop drifting
            }
            // one beat cycle == one full revolution (2π)
            if animated { clock.angle += clock.rotVel * 2 * .pi * dt * (1 - lock) }
        } else if animated {
            clock.angle += StrobeMath.ringSpeed(cents: err, lock: lock) * dt
        }

        let breath = input.isIdle ? 0.55 + 0.45 * sin(time * 1.4) : 1.0

        // colour for the current side, blended toward mint by proximity + lock
        let side = sign < 0 ? mix(pal.flat, pal.flat2, 0.35) : mix(pal.sharp, pal.sharp2, 0.35)
        let col = mix(side, pal.tune, max(prox * 0.7, lock))

        ctx.blendMode = light ? .normal : .plusLighter

        // faint base track
        let track = circlePath(cx, cy, R)
        ctx.stroke(track, with: .color(Color(pal.ink, opacity: 0.05)),
                   style: StrokeStyle(lineWidth: max(8, R * 0.13)))

        // phase marks (radial spokes whose brightness sweeps around the ring)
        let markLen = R * 0.20
        let markW = max(2.5, R * 0.045)
        let r0 = R - markLen / 2, r1 = R + markLen / 2
        for i in 0..<marks {
            let a = (Double(i) / Double(marks)) * 2 * .pi + clock.angle
            let env = StrobeMath.markEnvelope(angle: a)
            let alpha = (0.12 + 0.6 * env) * breath * (1 - lock * 0.35) * (light ? 0.6 : 1)
            if alpha < 0.01 { continue }
            let ca = cos(a), sa = sin(a)
            let p0 = CGPoint(x: cx + ca * r0, y: cy + sa * r0)
            let p1 = CGPoint(x: cx + ca * r1, y: cy + sa * r1)
            var spoke = Path()
            spoke.move(to: p0)
            spoke.addLine(to: p1)
            let grad = Gradient(stops: [
                .init(color: Color(col, opacity: alpha * 0.5), location: 0),
                .init(color: Color(col, opacity: alpha), location: 0.5),
                .init(color: Color(col, opacity: alpha * 0.5), location: 1)
            ])
            ctx.stroke(spoke, with: .linearGradient(grad, startPoint: p0, endPoint: p1),
                       style: StrokeStyle(lineWidth: markW, lineCap: .round))
        }

        // continuous solid ring as we converge / lock
        if lock > 0.01 || prox > 0.4 {
            let ringA = max(lock, (prox - 0.4) * 0.6)
            ctx.stroke(track,
                       with: .color(Color(mix(col, pal.tune, lock), opacity: 0.5 * ringA)),
                       style: StrokeStyle(lineWidth: markW * (1 + lock)))
        }

        // bloom halo at lock
        if lock > 0.01 {
            let bScale = light ? 0.55 : 1.0
            let halo = Gradient(stops: [
                .init(color: Color(pal.tune, opacity: 0.10 * lock * bScale), location: 0),
                .init(color: Color(pal.tune, opacity: 0.22 * lock * bScale), location: 0.45),
                .init(color: Color(pal.tune, opacity: 0.06 * lock * bScale), location: 0.7),
                .init(color: Color(pal.tune, opacity: 0), location: 1)
            ])
            ctx.fill(
                Path(CGRect(x: 0, y: 0, width: w, height: h)),
                with: .radialGradient(halo, center: CGPoint(x: cx, y: cy), startRadius: R * 0.2, endRadius: R * 1.5)
            )
        }
    }

    /// A full circle as a `Path` (centre `cx,cy`, radius `r`).
    private func circlePath(_ cx: Double, _ cy: Double, _ r: Double) -> Path {
        Path(ellipseIn: CGRect(x: cx - r, y: cy - r, width: 2 * r, height: 2 * r))
    }
}

#if DEBUG
private struct RadialDemo: View {
    let cents: Float
    var body: some View {
        RadialStrobe(input: StrobeInput(cents: cents, locked: Double(abs(cents)) < LumaMusic.lockCents))
            .frame(width: 360, height: 420)
            .background(Color.lumaBg)
    }
}

#Preview("Radial — flat (dark)") { RadialDemo(cents: -24).preferredColorScheme(.dark) }
#Preview("Radial — sharp (dark)") { RadialDemo(cents: 16).preferredColorScheme(.dark) }
#Preview("Radial — locked (dark)") { RadialDemo(cents: 0).preferredColorScheme(.dark) }
#Preview("Radial — flat (light)") { RadialDemo(cents: -24).preferredColorScheme(.light) }
#endif
