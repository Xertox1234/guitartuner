import SwiftUI

/// Picks the hero visualizer: the **Aurora** strobe, or the position-encoded
/// **ReducedGauge** when *Reduce Motion* is on — engaged automatically via the
/// environment (an equal, not a downgrade). Mirrors `StrobeField` in
/// `tuner-ui.jsx`. (The Radial strobe is a later, Settings-selectable variant.)
public struct StrobeField: View {
    var input: StrobeInput
    var idle: Bool
    var animated: Bool
    /// Force the reduced-motion gauge regardless of the system setting (for the
    /// harness / previews). `nil` honors `accessibilityReduceMotion` — which is
    /// read-only, so we can't inject it via `.environment`.
    var forceReduceMotion: Bool?

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    public init(input: StrobeInput, idle: Bool = false, animated: Bool = true, forceReduceMotion: Bool? = nil) {
        self.input = input
        self.idle = idle
        self.animated = animated
        self.forceReduceMotion = forceReduceMotion
    }

    private var usesReducedMotion: Bool { forceReduceMotion ?? reduceMotion }

    public var body: some View {
        if usesReducedMotion {
            ReducedGauge(cents: input.cents, locked: input.locked)
        } else {
            AuroraStrobe(input: input, idle: idle, animated: animated)
        }
    }
}

#if DEBUG
#Preview("Field — Aurora vs Gauge (dark)") {
    HStack(spacing: 0) {
        StrobeField(input: StrobeInput(cents: -18))
        StrobeField(input: StrobeInput(cents: -18), forceReduceMotion: true)
    }
    .frame(height: 380)
    .background(Color.lumaBg)
    .preferredColorScheme(.dark)
}
#endif
