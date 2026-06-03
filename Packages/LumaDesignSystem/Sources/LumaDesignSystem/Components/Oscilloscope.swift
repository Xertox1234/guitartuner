import SwiftUI
import Foundation

/// Mutable per-instance clock — integrated scroll phase + last frame time. A
/// reference type so the `Canvas` closure can advance it during redraws without
/// the "modifying state during view update" trap. Mirrors `AuroraClock`.
final class ScopeClock {
    var phase: Double = 0
    var last: Double = 0
}

/// **Oscilloscope** — the *optional* secondary scope (DESIGN_SYSTEM §Layout,
/// EXPERIENCE §11). A stylised live-waveform strip carried over from the alternate
/// exploration and recoloured into LUMA tokens: the trace takes the active
/// flat / sharp / in-tune glow, with a soft fill, a mirrored ghost, and a head dot;
/// it rests as a faint flat line when there's no signal.
///
/// Port of `docs/design_reference/oscilloscope.jsx`. The waveform is *synthesised*
/// from `freq` / `cents` (see `ScopeMath`), so it needs no engine frames — it
/// animates itself via `TimelineView`, pausing when inactive.
public struct Oscilloscope: View {
    var freq: Double
    var cents: Double
    var state: TunerVisualState
    /// `true` when there's a live signal — drives the full waveform; `false` rests
    /// on the flat baseline ("no signal").
    var active: Bool

    @State private var clock = ScopeClock()

    public init(freq: Double, cents: Double, state: TunerVisualState, active: Bool) {
        self.freq = freq
        self.cents = cents
        self.state = state
        self.active = active
    }

    public var body: some View {
        TimelineView(.animation(paused: !active)) { timeline in
            Canvas { context, size in
                draw(&context, size, time: timeline.date.timeIntervalSinceReferenceDate)
            }
        }
        .accessibilityHidden(true)
    }

    private func draw(_ ctx: inout GraphicsContext, _ size: CGSize, time: Double) {
        let w = Double(size.width), h = Double(size.height)
        guard w > 1, h > 1 else { return }
        let mid = h / 2

        // integrate the scroll phase from a freq-dependent rate
        var dt = 0.0
        if clock.last != 0 { dt = min(0.05, time - clock.last) }
        clock.last = time
        clock.phase += dt * ScopeMath.visualRate(freq: freq) * 2 * .pi
        let phase = clock.phase

        let accent: Color = active ? state.glow : .lumaFaint

        // centre baseline
        var center = Path()
        center.move(to: CGPoint(x: 0, y: mid))
        center.addLine(to: CGPoint(x: w, y: mid))
        ctx.stroke(center, with: .color(Color.lumaLine.opacity(0.35)), lineWidth: 1)

        // vertical graticule ticks
        var ticks = Path()
        for i in 1..<12 {
            let x = w * Double(i) / 12
            ticks.move(to: CGPoint(x: x, y: mid - 4))
            ticks.addLine(to: CGPoint(x: x, y: mid + 4))
        }
        ctx.stroke(ticks, with: .color(Color.lumaLine2.opacity(0.25)), lineWidth: 1)

        // build the trace
        let amplitude = active ? h * 0.38 : 0
        let cycles = ScopeMath.cycles(freq: freq)
        let count = 320
        var pts: [CGPoint] = []
        pts.reserveCapacity(count + 1)
        for i in 0...count {
            let u = Double(i) / Double(count)
            let y = ScopeMath.sample(u: u, phase: phase, cycles: cycles, cents: cents)
            pts.append(CGPoint(x: u * w, y: mid - y * (amplitude / 1.7)))
        }

        if active {
            // soft fill under the curve
            var fill = Path()
            fill.move(to: CGPoint(x: 0, y: mid))
            for p in pts { fill.addLine(to: p) }
            fill.addLine(to: CGPoint(x: w, y: mid))
            fill.closeSubpath()
            ctx.fill(fill, with: .color(accent.opacity(0.10)))

            // mirrored ghost
            var ghost = Path()
            for (i, p) in pts.enumerated() {
                let q = CGPoint(x: p.x, y: h - p.y)
                if i == 0 { ghost.move(to: q) } else { ghost.addLine(to: q) }
            }
            ctx.stroke(ghost, with: .color(accent.opacity(0.20)), lineWidth: 1)
        }

        // main waveform
        var wave = Path()
        for (i, p) in pts.enumerated() {
            if i == 0 { wave.move(to: p) } else { wave.addLine(to: p) }
        }
        ctx.stroke(wave,
                   with: .color(active ? accent : Color.lumaFaint.opacity(0.4)),
                   style: StrokeStyle(lineWidth: active ? 1.8 : 1, lineCap: .round, lineJoin: .round))

        // head dot
        if active, let last = pts.last {
            let r = 2.6
            ctx.fill(Path(ellipseIn: CGRect(x: last.x - r, y: last.y - r, width: 2 * r, height: 2 * r)),
                     with: .color(accent))
        }
    }
}

#if DEBUG
private struct ScopeDemo: View {
    var body: some View {
        VStack(spacing: 20) {
            Oscilloscope(freq: 146.8, cents: -6, state: .flat, active: true)
            Oscilloscope(freq: 329.6, cents: 0, state: .tune, active: true)
            Oscilloscope(freq: 0, cents: 0, state: .idle, active: false)
        }
        .frame(height: 220)
        .padding(24)
        .background(Color.lumaBg)
    }
}

#Preview("Scope — dark") { ScopeDemo().preferredColorScheme(.dark) }
#Preview("Scope — light") { ScopeDemo().preferredColorScheme(.light) }
#endif
