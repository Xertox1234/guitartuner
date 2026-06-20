import SwiftUI

/// Soft radial wash in the active glow hue, sitting behind the hero field.
/// Mirrors `.field-wash` in `ds-tokens.css`:
/// `radial-gradient(60% 50% at 50% 42%, glow 16%, transparent 72%)`.
public struct FieldWash: View {
    @Environment(\.lumaGlow) private var glow
    @Environment(\.accessibilityReduceTransparency) private var reduceTransparency

    public init() {}

    public var body: some View {
        GeometryReader { geo in
            let maxDim = max(geo.size.width, geo.size.height)
            RadialGradient(
                gradient: Gradient(stops: [
                    .init(color: glow.opacity(Translucency.attenuated(0.16, reduceTransparency: reduceTransparency)), location: 0),
                    .init(color: .clear, location: 0.72)
                ]),
                center: UnitPoint(x: 0.5, y: 0.42),
                startRadius: 0,
                endRadius: maxDim * 0.6
            )
        }
    }
}

public extension View {
    /// Place a `FieldWash` behind this view.
    func fieldWash() -> some View {
        background(FieldWash())
    }
}

/// The LUMA screen shell background — the cool radial canvas (`bg-grad → bg`)
/// plus the ambient corner wash in the active glow hue. Mirrors `.scr` and
/// `.scr::before` in `ds-components.css`.
public struct ScreenBackground: View {
    @Environment(\.lumaGlow) private var glow
    @Environment(\.accessibilityReduceTransparency) private var reduceTransparency

    public init() {}

    public var body: some View {
        GeometryReader { geo in
            let maxDim = max(geo.size.width, geo.size.height)
            ZStack {
                // Base canvas: opaque — stays under Reduce Transparency.
                RadialGradient(
                    gradient: Gradient(stops: [
                        .init(color: .lumaBgGrad, location: 0),
                        .init(color: .lumaBg, location: 0.6)
                    ]),
                    center: UnitPoint(x: 0.5, y: -0.1),
                    startRadius: 0,
                    endRadius: maxDim * 1.2
                )
                // Ambient glow wash: translucency — removed under Reduce Transparency.
                RadialGradient(
                    gradient: Gradient(stops: [
                        .init(color: glow.opacity(Translucency.attenuated(0.09, reduceTransparency: reduceTransparency)), location: 0),
                        .init(color: .clear, location: 0.7)
                    ]),
                    center: UnitPoint(x: 0.5, y: 0.38),
                    startRadius: 0,
                    endRadius: maxDim * 0.55
                )
                .animation(.easeInOut(duration: 0.6), value: glow)
            }
        }
        .ignoresSafeArea()
    }
}

#if DEBUG
#Preview("Screen background — dark") {
    ScreenBackground()
        .lumaGlow(.lumaInTune)
        .preferredColorScheme(.dark)
}

#Preview("Field wash — sharp") {
    FieldWash()
        .lumaGlow(.lumaSharp)
        .frame(width: 320, height: 480)
        .background(Color.lumaBg)
        .preferredColorScheme(.dark)
}

// NOTE: accessibilityReduceTransparency is get-only in this SDK and cannot be
// forced via .environment(_:_:) in a code Preview. The trait routing is verified
// by TranslucencyTests. To see zero-wash visually, use Accessibility Inspector
// or the Simulator's Reduce Transparency setting.
#Preview("Screen background — reduce transparency (see note above)") {
    ScreenBackground()
        .lumaGlow(.lumaInTune)
        .preferredColorScheme(.dark)
}

#Preview("Field wash — reduce transparency (see note above)") {
    FieldWash()
        .lumaGlow(.lumaSharp)
        .frame(width: 320, height: 480)
        .background(Color.lumaBg)
        .preferredColorScheme(.light)
}
#endif
