import SwiftUI

public enum InputKind: String, CaseIterable, Sendable {
    case di, mic
    public var label: String { self == .di ? "DI" : "MIC" }
    /// DI-first per `DESIGN_SYSTEM.md`.
    public var systemImage: String { self == .di ? "cable.connector" : "mic" }
}

/// Edge-chrome input toggle: a live mint dot + icon + DI / MIC label. DI is the
/// default source. Mirrors `.edge-btn` / `InputSource` in the export.
public struct InputSource: View {
    @Binding var source: InputKind

    public init(source: Binding<InputKind>) {
        self._source = source
    }

    public var body: some View {
        Button {
            source = (source == .di) ? .mic : .di
        } label: {
            HStack(spacing: 7) {
                Circle()
                    .fill(Color.lumaInTune)
                    .frame(width: 7, height: 7)
                    .shadow(color: Color.lumaInTune.opacity(0.9), radius: 3.5)
                Image(systemName: source.systemImage)
                    .font(.system(size: 14))
                Text(source.label)
            }
        }
        .buttonStyle(EdgeButtonStyle())
        .accessibilityLabel("Input source")
        .accessibilityValue(source == .di ? "Direct input" : "Microphone")
    }
}

#if DEBUG
private struct InputSourceDemo: View {
    @State private var source: InputKind = .di
    var body: some View {
        HStack(spacing: 16) {
            InputSource(source: $source)
            InputSource(source: .constant(.mic))
        }
        .padding(40)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color.lumaBg)
    }
}

#Preview("Input source — dark") { InputSourceDemo().preferredColorScheme(.dark) }
#Preview("Input source — light") { InputSourceDemo().preferredColorScheme(.light) }
#endif
