import SwiftUI

/// Picks the hero visualizer: the selected **strobe** (`AuroraStrobe` or
/// `RadialStrobe`, per `style`), or the position-encoded **ReducedGauge** when
/// *Reduce Motion* is on — engaged automatically via the environment (an equal, not
/// a downgrade), and overriding the style choice. Mirrors `StrobeField` in
/// `tuner-ui.jsx`.
public struct StrobeField: View {
    var input: StrobeInput
    var animated: Bool
    /// Which hero strobe to render (ignored under Reduce Motion). Default `.aurora`.
    var style: StrobeStyle
    /// Force the reduced-motion gauge regardless of the system setting (for the
    /// harness / previews). `nil` honors `accessibilityReduceMotion` — which is
    /// read-only, so we can't inject it via `.environment`.
    var forceReduceMotion: Bool?
    /// Drive the strobe scroll/rotation from the engine's live `phase` (true strobe)
    /// rather than the cents-derived approximation. Default `false` (simulator path).
    var phaseScroll: Bool
    /// Render with the Metal hero path instead of Canvas. Off by default; ignored
    /// under Reduce Motion. Supported for both `.aurora` (`MetalStrobe`) and
    /// `.radial` (`RadialMetalStrobe`).
    var useMetalRenderer: Bool

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    public init(input: StrobeInput, animated: Bool = true, style: StrobeStyle = .aurora, forceReduceMotion: Bool? = nil, phaseScroll: Bool = false, useMetalRenderer: Bool = false) {
        self.input = input
        self.animated = animated
        self.style = style
        self.forceReduceMotion = forceReduceMotion
        self.phaseScroll = phaseScroll
        self.useMetalRenderer = useMetalRenderer
    }

    private var usesReducedMotion: Bool { forceReduceMotion ?? reduceMotion }

    public var body: some View {
        if usesReducedMotion {
            ReducedGauge(cents: Double(input.cents), locked: input.locked)
        } else {
            switch style {
            case .aurora:
                if useMetalRenderer {
                    MetalStrobe(input: input, animated: animated, phaseScroll: phaseScroll)
                } else {
                    AuroraStrobe(input: input, animated: animated, phaseScroll: phaseScroll)
                }
            case .radial:
                if useMetalRenderer {
                    RadialMetalStrobe(input: input, animated: animated, phaseScroll: phaseScroll)
                } else {
                    RadialStrobe(input: input, animated: animated, phaseScroll: phaseScroll)
                }
            }
        }
    }
}

#if DEBUG
#Preview("Field — Aurora · Radial · Gauge (dark)") {
    HStack(spacing: 0) {
        StrobeField(input: StrobeInput(cents: -18), style: .aurora)
        StrobeField(input: StrobeInput(cents: -18), style: .radial)
        StrobeField(input: StrobeInput(cents: -18), forceReduceMotion: true)
    }
    .frame(height: 380)
    .background(Color.lumaBg)
    .preferredColorScheme(.dark)
}
#endif
