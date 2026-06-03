import SwiftUI

/// Signed cents readout in tabular mono, with a direction arrow: ▲ when flat
/// (tune up), ▼ when sharp (tune down), hidden when in tune. Colour follows the
/// state but the sign + arrow carry the meaning too. Mirrors `.cents` /
/// `CentsReadout` in the export.
public struct CentsReadout: View {
    let cents: Double
    let state: TunerVisualState

    public init(cents: Double, state: TunerVisualState) {
        self.cents = cents
        self.state = state
    }

    private var value: Int { Int(cents.rounded()) }
    private var sign: String { value > 0 ? "+" : (value < 0 ? "\u{2212}" : "\u{00B1}") }
    private var magnitude: Int { abs(value) }

    private var arrow: String? {
        switch state {
        case .flat: "arrowtriangle.up.fill"
        case .sharp: "arrowtriangle.down.fill"
        case .tune, .idle: nil
        }
    }

    public var body: some View {
        HStack(spacing: 8) {
            Image(systemName: arrow ?? "arrowtriangle.up.fill")
                .font(.system(size: 10))
                .opacity(arrow == nil ? 0 : 1)
                .accessibilityHidden(true)
            Text("\(sign)\(magnitude)")
                .font(.lumaCents)
            Text("\u{00A2}")
                .font(LumaFont.mono(16))
                .foregroundStyle(Color.lumaDim)
        }
        .foregroundStyle(state.accent)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(magnitude) cents \(state == .flat ? "flat" : state == .sharp ? "sharp" : "in tune")")
    }
}

#if DEBUG
private struct CentsGallery: View {
    var body: some View {
        VStack(spacing: 24) {
            CentsReadout(cents: -6, state: .flat)
            CentsReadout(cents: 4, state: .sharp)
            CentsReadout(cents: 0, state: .tune)
        }
        .padding(40)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color.lumaBg)
    }
}

#Preview("Cents — dark") { CentsGallery().preferredColorScheme(.dark) }
#Preview("Cents — light") { CentsGallery().preferredColorScheme(.light) }
#endif
