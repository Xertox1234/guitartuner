import SwiftUI

/// Reference-pitch stepper: `A4  −  440 Hz  +`, clamped to 430–450. Tabular so
/// the value never jitters. Mirrors `.a4` / `A4Control` in the export.
public struct A4Control: View {
    @Binding var a4: Int

    public static let range = 430...450

    public init(a4: Binding<Int>) {
        self._a4 = a4
    }

    public var body: some View {
        HStack(spacing: 8) {
            Text("A4").foregroundStyle(Color.lumaFaint)
            step("\u{2212}", "Lower A4") { a4 = max(Self.range.lowerBound, a4 - 1) }
            Text("\(a4) Hz")
                .foregroundStyle(Color.lumaInk)
                .frame(minWidth: 58)
            step("+", "Raise A4") { a4 = min(Self.range.upperBound, a4 + 1) }
        }
        .font(LumaFont.mono(11, relativeTo: .caption2))
        .lumaTracking(0.08, size: 11)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("A4 reference")
        .accessibilityValue("\(a4) hertz")
    }

    private func step(_ glyph: String, _ label: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(glyph)
                .font(.system(size: 13))
                .foregroundStyle(Color.lumaDim)
                .frame(width: 22, height: 22)
                .overlay(RoundedRectangle(cornerRadius: 7, style: .continuous).stroke(Color.lumaLine2, lineWidth: 1))
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(label)
    }
}

#if DEBUG
private struct A4Demo: View {
    @State private var a4 = 440
    var body: some View {
        A4Control(a4: $a4)
            .padding(40)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(Color.lumaBg)
    }
}

#Preview("A4 — dark") { A4Demo().preferredColorScheme(.dark) }
#Preview("A4 — light") { A4Demo().preferredColorScheme(.light) }
#endif
