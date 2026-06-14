import SwiftUI
import Foundation

/// Reduce-Motion fallback — **not a downgrade**: a luminous arc + eased needle +
/// position-encoded error (sign + colour too, never colour alone). No flashing
/// motion. Ported from `docs/design_reference/strobe-reduced.jsx`.
public struct ReducedGauge: View {
    var cents: Double
    var locked: Bool

    @Environment(\.lumaPalette) private var palette
    @Environment(\.colorScheme) private var scheme

    public init(cents: Double, locked: Bool) {
        self.cents = cents
        self.locked = locked
    }

    public var body: some View {
        let tuneColor = Color(StrobePalette.resolve(scheme, palette: palette).tune, opacity: 1)
        Canvas { context, size in
            draw(&context, size, tuneColor: tuneColor)
        }
        .accessibilityElement()
        .accessibilityLabel("Tuning gauge")
        .accessibilityValue(gaugeValueDescription)
    }

    private var gaugeValueDescription: String {
        if locked { return "in tune" }
        let mag = Int(abs(cents).rounded())
        return cents < 0 ? "\(mag) cents flat" : "\(mag) cents sharp"
    }

    private func draw(_ ctx: inout GraphicsContext, _ size: CGSize, tuneColor: Color) {
        // Fit the 220×220 viewBox from the export, then draw in those coordinates.
        let s = min(size.width, size.height) / 220
        guard s > 0 else { return }
        ctx.translateBy(x: (size.width - 220 * s) / 2, y: (size.height - 220 * s) / 2)
        ctx.scaleBy(x: s, y: s)

        let cx = 110.0, cy = 124.0, R = 86.0
        let span = StrobeMath.gaugeSpan
        let a = StrobeMath.gaugeAngle(cents: cents)
        let glow: Color = locked ? tuneColor
            : (cents < -0.001 ? .lumaFlat : (cents > 0.001 ? .lumaSharp : .lumaInk))

        // track
        ctx.stroke(arc(cx, cy, R, -span, span),
                   with: .color(.lumaLine),
                   style: StrokeStyle(lineWidth: 3, lineCap: .round))

        // coloured fill from 0 to the needle (with glow)
        ctx.drawLayer { layer in
            layer.addFilter(.shadow(color: glow.opacity(0.7), radius: 6))
            layer.stroke(arc(cx, cy, R, min(0, a), max(0, a)),
                         with: .color(glow),
                         style: StrokeStyle(lineWidth: 4.5, lineCap: .round))
        }

        // ticks every 5¢, major every 25¢, accent at 0
        for cc in stride(from: -50.0, through: 50.0, by: 5.0) {
            let ta = StrobeMath.gaugeAngle(cents: cc)
            let isCenter = cc == 0
            let major = Int(cc) % 25 == 0
            let p0 = polar(cx, cy, R - (major ? 16 : 9), ta)
            let p1 = polar(cx, cy, R, ta)
            var tick = Path()
            tick.move(to: p0)
            tick.addLine(to: p1)
            ctx.stroke(tick,
                       with: .color(isCenter ? tuneColor : .lumaLine2),
                       style: StrokeStyle(lineWidth: isCenter ? 2.4 : (major ? 1.6 : 1), lineCap: .round))
        }

        // needle
        let tip = polar(cx, cy, R - 4, a)
        ctx.drawLayer { layer in
            layer.addFilter(.shadow(color: glow.opacity(0.6), radius: 5))
            var needle = Path()
            needle.move(to: CGPoint(x: cx, y: cy))
            needle.addLine(to: tip)
            layer.stroke(needle, with: .color(glow), style: StrokeStyle(lineWidth: 2.6, lineCap: .round))
            let r = locked ? 6.0 : 4.2
            layer.fill(Path(ellipseIn: CGRect(x: tip.x - r, y: tip.y - r, width: 2 * r, height: 2 * r)), with: .color(glow))
        }

        // hub
        let hub = CGRect(x: cx - 4, y: cy - 4, width: 8, height: 8)
        ctx.fill(Path(ellipseIn: hub), with: .color(.lumaSurface3))
        ctx.stroke(Path(ellipseIn: hub), with: .color(.lumaLine2), lineWidth: 1)

        // lock ring
        if locked {
            ctx.drawLayer { layer in
                layer.addFilter(.shadow(color: tuneColor.opacity(0.8), radius: 10))
                let rr = R + 8
                layer.stroke(Path(ellipseIn: CGRect(x: cx - rr, y: cy - rr, width: 2 * rr, height: 2 * rr)),
                             with: .color(tuneColor.opacity(0.35)),
                             lineWidth: 1.5)
            }
        }
    }

    /// Point on a circle; `deg` is 0 at top (up), increasing clockwise.
    private func polar(_ cx: Double, _ cy: Double, _ r: Double, _ deg: Double) -> CGPoint {
        let rad = (deg - 90) * .pi / 180
        return CGPoint(x: cx + r * cos(rad), y: cy + r * sin(rad))
    }

    /// Arc sampled as a polyline (avoids `addArc` direction ambiguity).
    private func arc(_ cx: Double, _ cy: Double, _ r: Double, _ a0: Double, _ a1: Double) -> Path {
        var path = Path()
        let steps = max(2, Int((abs(a1 - a0) / 2).rounded(.up)))
        for i in 0...steps {
            let t = Double(i) / Double(steps)
            let pt = polar(cx, cy, r, a0 + (a1 - a0) * t)
            if i == 0 { path.move(to: pt) } else { path.addLine(to: pt) }
        }
        return path
    }
}

#if DEBUG
private struct GaugeDemo: View {
    let cents: Double
    var body: some View {
        ReducedGauge(cents: cents, locked: abs(cents) < LumaMusic.lockCents)
            .frame(width: 280, height: 280)
            .background(Color.lumaBg)
    }
}

#Preview("Gauge — flat (dark)") { GaugeDemo(cents: -22).preferredColorScheme(.dark) }
#Preview("Gauge — locked (dark)") { GaugeDemo(cents: 0).preferredColorScheme(.dark) }
#Preview("Gauge — sharp (light)") { GaugeDemo(cents: 31).preferredColorScheme(.light) }
#endif
