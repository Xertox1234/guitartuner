import SwiftUI

/// Picks the hero visualizer: the **Aurora** strobe, or the position-encoded
/// **ReducedGauge** when *Reduce Motion* is on — engaged automatically via the
/// environment (an equal, not a downgrade). Mirrors `StrobeField` in
/// `tuner-ui.jsx`. (The Radial strobe is a later, Settings-selectable variant.)
public struct StrobeField: View {
    var input: StrobeInput
    var idle: Bool
    var animated: Bool

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    public init(input: StrobeInput, idle: Bool = false, animated: Bool = true) {
        self.input = input
        self.idle = idle
        self.animated = animated
    }

    public var body: some View {
        if reduceMotion {
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
        StrobeField(input: StrobeInput(cents: -18))
            .environment(\.accessibilityReduceMotion, true)
    }
    .frame(height: 380)
    .background(Color.lumaBg)
    .preferredColorScheme(.dark)
}
#endif
