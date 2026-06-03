import SwiftUI

public enum TargetMode: String, CaseIterable, Identifiable, Sendable {
    case auto, lock
    public var id: String { rawValue }
    public var label: String { self == .auto ? "Auto" : "String" }
}

/// Segmented pill toggling chromatic **Auto** vs **String**-lock targeting, with
/// a sliding `ink` glider behind the selection. Mirrors `.target` / `TargetChip`.
public struct TargetChip: View {
    @Binding var mode: TargetMode
    @Namespace private var glider

    public init(mode: Binding<TargetMode>) {
        self._mode = mode
    }

    public var body: some View {
        HStack(spacing: 0) {
            ForEach(TargetMode.allCases) { option in
                let selected = mode == option
                Text(option.label)
                    .font(LumaFont.mono(11))
                    .lumaTracking(Tracking.chipWide, size: 11)
                    .textCase(.uppercase)
                    .foregroundStyle(selected ? Color.lumaBg : Color.lumaDim)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 7)
                    .background {
                        if selected {
                            Capsule()
                                .fill(Color.lumaInk)
                                .matchedGeometryEffect(id: "glider", in: glider)
                        }
                    }
                    .contentShape(Capsule())
                    .onTapGesture {
                        withAnimation(.spring(response: 0.32, dampingFraction: 0.82)) {
                            mode = option
                        }
                    }
                    .accessibilityAddTraits(selected ? [.isSelected, .isButton] : .isButton)
                    .accessibilityLabel("\(option.label) targeting")
            }
        }
        .padding(3)
        .background(Color.lumaSurface.opacity(0.5), in: Capsule())
        .overlay(Capsule().stroke(Color.lumaLine2, lineWidth: 1))
    }
}

#if DEBUG
private struct TargetChipDemo: View {
    @State private var mode: TargetMode = .auto
    var body: some View {
        TargetChip(mode: $mode)
            .padding(40)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(Color.lumaBg)
    }
}

#Preview("Target chip — dark") { TargetChipDemo().preferredColorScheme(.dark) }
#Preview("Target chip — light") { TargetChipDemo().preferredColorScheme(.light) }
#endif
