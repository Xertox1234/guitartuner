import SwiftUI

/// A row of selectable string cells for the current tuning, rendered low→high.
/// A cell can be plain, active (selected), or locked (in tune → palette tune colour
/// + glow). Mirrors `.stringrow` / `.string` / `StringRow` in the export.
public struct StringRow: View {
    let tuning: Tuning
    @Binding var activeIdx: Int?
    var lockedIdx: Int?
    var onPick: ((Int) -> Void)?

    public init(
        tuning: Tuning,
        activeIdx: Binding<Int?>,
        lockedIdx: Int? = nil,
        onPick: ((Int) -> Void)? = nil
    ) {
        self.tuning = tuning
        self._activeIdx = activeIdx
        self.lockedIdx = lockedIdx
        self.onPick = onPick
    }

    public var body: some View {
        HStack(spacing: Space.s3) {
            ForEach(tuning.strings) { string in
                Button {
                    activeIdx = string.idx
                    onPick?(string.idx)
                } label: {
                    StringCell(
                        string: string,
                        active: activeIdx == string.idx,
                        locked: lockedIdx == string.idx
                    )
                }
                .buttonStyle(.plain)
                .frame(maxWidth: 64)
            }
        }
    }
}

struct StringCell: View {
    let string: GuitarString
    var active: Bool
    var locked: Bool

    @Environment(\.lumaPalette) private var palette
    @Environment(\.colorScheme) private var scheme

    private var tuneColor: Color {
        Color(StrobePalette.resolve(scheme, palette: palette).tune, opacity: 1)
    }

    private var borderColor: Color {
        if locked { return tuneColor }
        if active { return Color.lumaInk.opacity(0.4) }
        return .lumaLine2
    }

    private var fillColor: Color {
        if locked { return tuneColor.opacity(0.16) }
        if active { return Color.lumaSurface3.opacity(0.8) }
        return Color.lumaSurface.opacity(0.45)
    }

    var body: some View {
        VStack(spacing: 2) {
            Text(string.note)
                .font(LumaFont.display(21, weight: .semibold))
                .foregroundStyle(locked ? tuneColor : Color.lumaInk)
            Text("\(string.octave)")
                .font(LumaFont.mono(8.5))
                .foregroundStyle(active || locked ? Color.lumaDim : Color.lumaFaint)
        }
        .frame(maxWidth: .infinity)
        .aspectRatio(1 / 1.18, contentMode: .fit)
        .overlay(alignment: .topLeading) {
            Text(String(format: "%02d", string.idx))
                .font(LumaFont.mono(7.5))
                .foregroundStyle(Color.lumaFaint)
                .padding(.top, 4)
                .padding(.leading, 6)
        }
        .background(fillColor, in: RoundedRectangle(cornerRadius: Radius.r2, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: Radius.r2, style: .continuous)
                .stroke(borderColor, lineWidth: 1)
        )
        .shadow(color: locked ? tuneColor.opacity(0.30) : .clear, radius: 9)
        .scaleEffect(active || locked ? 1.0 : 0.95)
        .animation(.spring(response: 0.28, dampingFraction: 0.52), value: active || locked)
        .accessibilityLabel("String \(string.idx), \(string.note)\(string.octave)")
        .accessibilityAddTraits(active ? [.isSelected, .isButton] : .isButton)
    }
}

#if DEBUG
private struct StringRowDemo: View {
    @State private var active: Int? = 5
    var body: some View {
        VStack(spacing: 28) {
            StringRow(tuning: Tunings.guitar, activeIdx: $active)
            StringRow(tuning: Tunings.guitar, activeIdx: .constant(5), lockedIdx: 5)
            StringRow(tuning: Tunings.bass, activeIdx: .constant(4))
        }
        .padding(24)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color.lumaBg)
    }
}

#Preview("String row — dark") { StringRowDemo().preferredColorScheme(.dark) }
#Preview("String row — light") { StringRowDemo().preferredColorScheme(.light) }
#endif
