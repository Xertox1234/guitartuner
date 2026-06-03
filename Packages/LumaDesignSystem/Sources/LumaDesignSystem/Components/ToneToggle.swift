import SwiftUI

/// Reference tone-generator toggle. When on, it glows mint and the waveform
/// pulses. Mirrors `.tone` / `ToneToggle` in the export.
public struct ToneToggle: View {
    @Binding var on: Bool
    var label: String

    public init(on: Binding<Bool>, label: String = "Tone") {
        self._on = on
        self.label = label
    }

    public var body: some View {
        Button {
            on.toggle()
        } label: {
            HStack(spacing: 9) {
                Image(systemName: "waveform")
                    .font(.system(size: 15))
                    .symbolEffect(.pulse, isActive: on)
                Text(label)
            }
        }
        .buttonStyle(EdgeButtonStyle(active: on, activeColor: .lumaInTune))
        .accessibilityLabel("Tone generator")
        .accessibilityValue(on ? "On" : "Off")
        .accessibilityAddTraits(on ? .isSelected : [])
    }
}

#if DEBUG
private struct ToneDemo: View {
    @State private var on = false
    var body: some View {
        HStack(spacing: 16) {
            ToneToggle(on: $on)
            ToneToggle(on: .constant(true))
        }
        .padding(40)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color.lumaBg)
    }
}

#Preview("Tone — dark") { ToneDemo().preferredColorScheme(.dark) }
#Preview("Tone — light") { ToneDemo().preferredColorScheme(.light) }
#endif
