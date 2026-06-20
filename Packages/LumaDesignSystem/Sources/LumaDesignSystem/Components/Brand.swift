import SwiftUI

/// The LUMA wordmark: a luminous mint dot + the display-type word. Mirrors
/// `.brand-min` / `.brand-dot` / `.brand-word` in `ds-components.css`.
public struct Brand: View {
    var label: String

    public init(label: String = "LUMA") {
        self.label = label
    }

    public var body: some View {
        HStack(spacing: 10) {
            BrandDot()
            Text(label)
                .font(LumaFont.display(LumaFont.Size.label, weight: .semibold, relativeTo: .caption))
                .lumaTracking(Tracking.tag, size: LumaFont.Size.label)
                .foregroundStyle(Color.lumaInk)
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel(label)
    }
}

/// The 22×22 brand dot — a glowing rounded square in the sacred mint.
public struct BrandDot: View {
    public init() {}
    public var body: some View {
        RoundedRectangle(cornerRadius: 7, style: .continuous)
            .fill(
                RadialGradient(
                    gradient: Gradient(colors: [.lumaInTune, Color.lumaInTune.opacity(0.35)]),
                    center: UnitPoint(x: 0.5, y: 0.38),
                    startRadius: 0,
                    endRadius: 16
                )
            )
            .frame(width: 22, height: 22)
            .overlay(
                RoundedRectangle(cornerRadius: 7, style: .continuous)
                    .stroke(Color.lumaInTune.opacity(0.4), lineWidth: 1)
            )
            .shadow(color: Color.lumaInTune.opacity(0.55), radius: 5)
    }
}

#if DEBUG
#Preview("Brand — dark") {
    Brand()
        .padding(40)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color.lumaBg)
        .preferredColorScheme(.dark)
}

#Preview("Brand — light") {
    Brand()
        .padding(40)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color.lumaBg)
        .preferredColorScheme(.light)
}
#endif
