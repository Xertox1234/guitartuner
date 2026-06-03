import SwiftUI

// MARK: - Active glow hue

private struct LumaGlowKey: EnvironmentKey {
    static let defaultValue: Color = .lumaFaint
}

public extension EnvironmentValues {
    /// The currently-active glow hue (`--glow`). Components set this per state
    /// (flat / sharp / in-tune / idle); `.bloom(_:)` and `.fieldWash()` read it.
    var lumaGlow: Color {
        get { self[LumaGlowKey.self] }
        set { self[LumaGlowKey.self] = newValue }
    }
}

public extension View {
    /// Set the active glow hue for this subtree.
    func lumaGlow(_ color: Color) -> some View {
        environment(\.lumaGlow, color)
    }

    /// Set the active glow hue from a tuner state.
    func lumaGlow(_ state: TunerVisualState) -> some View {
        environment(\.lumaGlow, state.glow)
    }
}

// MARK: - Bloom

/// Additive luminosity elevation — *glow, not drop-shadows*. Each level layers a
/// tight core glow + softer outer blooms in the active `lumaGlow` hue. Mirrors
/// `.bloom-1/2/3` and `.bloom-text` in `ds-tokens.css` (CSS blur radii are
/// roughly halved for SwiftUI's shadow radius).
public enum BloomLevel: Sendable, Hashable {
    case l1    // core
    case l2    // near
    case l3    // lock
    case text  // the locked-note reward
}

public extension View {
    func bloom(_ level: BloomLevel) -> some View {
        modifier(BloomModifier(level: level))
    }
}

struct BloomModifier: ViewModifier {
    let level: BloomLevel
    @Environment(\.lumaGlow) private var glow

    @ViewBuilder
    func body(content: Content) -> some View {
        switch level {
        case .l1:
            content
                .shadow(color: glow.opacity(0.55), radius: 2)
        case .l2:
            content
                .shadow(color: glow.opacity(0.60), radius: 3)
                .shadow(color: glow.opacity(0.30), radius: 8)
        case .l3:
            content
                .shadow(color: glow.opacity(0.70), radius: 4)
                .shadow(color: glow.opacity(0.40), radius: 12)
                .shadow(color: glow.opacity(0.22), radius: 28)
        case .text:
            content
                .shadow(color: glow.opacity(0.45), radius: 6)
                .shadow(color: glow.opacity(0.25), radius: 20)
        }
    }
}

#if DEBUG
#Preview("Bloom levels — dark") {
    HStack(spacing: 30) {
        ForEach([BloomLevel.l1, .l2, .l3], id: \.self) { level in
            RoundedRectangle(cornerRadius: Radius.r3)
                .fill(Color.lumaInTune)
                .frame(width: 60, height: 60)
                .bloom(level)
        }
    }
    .lumaGlow(.lumaInTune)
    .padding(60)
    .frame(maxWidth: .infinity, maxHeight: .infinity)
    .background(Color.lumaBg)
    .preferredColorScheme(.dark)
}
#endif
