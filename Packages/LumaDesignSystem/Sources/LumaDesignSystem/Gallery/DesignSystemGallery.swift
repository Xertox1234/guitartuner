import SwiftUI

/// The Design-System Gallery — token + component documentation, the visual
/// reference vs the export. Mirrors `foundations.jsx`. Scrollable: colour
/// swatches, type scale, spacing/radius, glow levels, and the component library.
public struct DesignSystemGallery: View {
    public init() {}

    public var body: some View {
        ScrollView {
            VStack(spacing: Space.s5) {
                ColorTokensCard()
                TypeScaleCard()
                SpaceRadiusCard()
                GlowScaleCard()
                ComponentLibCard()
            }
            .padding(Space.s5)
        }
        .background(ScreenBackground().lumaGlow(.lumaInTune))
        .foregroundStyle(Color.lumaInk)
    }
}

// MARK: - Card scaffolding

struct GalleryCard<Content: View>: View {
    let kicker: String
    let title: String
    @ViewBuilder var content: Content

    var body: some View {
        VStack(alignment: .leading, spacing: Space.s6) {
            VStack(alignment: .leading, spacing: 6) {
                Text(kicker)
                    .font(LumaFont.mono(10))
                    .lumaTracking(0.2, size: 10)
                    .textCase(.uppercase)
                    .foregroundStyle(Color.lumaDim)
                Text(title)
                    .font(.lumaTitle)
                    .foregroundStyle(Color.lumaInk)
            }
            content
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(Space.s7)
        .background(Color.lumaSurface.opacity(0.5), in: RoundedRectangle(cornerRadius: Radius.r4, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: Radius.r4, style: .continuous)
                .stroke(Color.lumaLine, lineWidth: 1)
        )
    }
}

// MARK: - Colour

struct ColorTokensCard: View {
    private let neutrals: [LumaColor] = [.bg, .surface, .surface2, .ink, .dim, .faint]
    private let signal: [LumaColor] = [.flat, .flat2, .sharp, .sharp2, .inTune, .inTune2]

    private let columns = [GridItem(.flexible()), GridItem(.flexible())]

    var body: some View {
        GalleryCard(kicker: "Color", title: "Semantic tokens") {
            LazyVGrid(columns: columns, alignment: .leading, spacing: Space.s5) {
                ForEach(neutrals) { Swatch(token: $0, glow: false) }
            }
            Divider().overlay(Color.lumaLine)
            Text("Error coding — never colour alone")
                .font(LumaFont.mono(10))
                .lumaTracking(Tracking.wide, size: 10)
                .textCase(.uppercase)
                .foregroundStyle(Color.lumaDim)
            LazyVGrid(columns: columns, alignment: .leading, spacing: Space.s5) {
                ForEach(signal) { Swatch(token: $0, glow: true) }
            }
        }
    }
}

struct Swatch: View {
    let token: LumaColor
    var glow: Bool

    var body: some View {
        HStack(spacing: 14) {
            RoundedRectangle(cornerRadius: Radius.r2, style: .continuous)
                .fill(token.color)
                .frame(width: 46, height: 46)
                .overlay(
                    RoundedRectangle(cornerRadius: Radius.r2, style: .continuous)
                        .stroke(Color.lumaLine2, lineWidth: 1)
                )
                .shadow(color: glow ? token.color.opacity(0.55) : .clear, radius: 9)
            VStack(alignment: .leading, spacing: 2) {
                Text(token.label)
                    .font(LumaFont.display(14, weight: .semibold))
                    .foregroundStyle(Color.lumaInk)
                Text("--\(token.rawValue)")
                    .font(LumaFont.mono(11))
                    .foregroundStyle(Color.lumaDim)
            }
            Spacer(minLength: 0)
        }
    }
}

// MARK: - Type

struct TypeScaleCard: View {
    private struct Row: Identifiable {
        let id = UUID()
        let role: String
        let font: Font
        let size: CGFloat
        let weight: String
        let sample: String
    }

    private var rows: [Row] {
        [
            Row(role: "Display · note", font: LumaFont.display(40), size: 40, weight: "600", sample: "A\u{266F}"),
            Row(role: "Numerals · cents", font: LumaFont.mono(32, weight: .medium), size: 32, weight: "500", sample: "\u{2212}4\u{00A2}"),
            Row(role: "Numerals · freq", font: LumaFont.mono(22, weight: .medium), size: 22, weight: "500", sample: "146.8 Hz"),
            Row(role: "UI · title", font: LumaFont.ui(20, weight: .semibold), size: 20, weight: "600", sample: "In tune"),
            Row(role: "UI · label", font: LumaFont.ui(15, weight: .medium), size: 15, weight: "500", sample: "Tune up"),
            Row(role: "Mono · eyebrow", font: LumaFont.mono(11), size: 11, weight: "500", sample: "STANDBY")
        ]
    }

    var body: some View {
        GalleryCard(kicker: "Type", title: "Chakra Petch · JetBrains Mono · System") {
            VStack(spacing: Space.s5) {
                ForEach(rows) { row in
                    HStack(alignment: .firstTextBaseline) {
                        Text(row.sample)
                            .font(row.font)
                            .foregroundStyle(Color.lumaInk)
                        Spacer(minLength: Space.s5)
                        VStack(alignment: .trailing, spacing: 2) {
                            Text(row.role).font(LumaFont.ui(12)).foregroundStyle(Color.lumaInk)
                            Text("\(Int(row.size))pt / \(row.weight)")
                                .font(LumaFont.mono(10)).foregroundStyle(Color.lumaDim)
                        }
                    }
                    Divider().overlay(Color.lumaLine)
                }
                Text("Numerals are tabular everywhere — cents, Hz and A4 never jitter as values change.")
                    .font(LumaFont.mono(10.5))
                    .foregroundStyle(Color.lumaDim)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
    }
}

// MARK: - Spacing + Radius

struct SpaceRadiusCard: View {
    private let space: [(String, CGFloat)] = [
        ("s-2", 4), ("s-3", 8), ("s-4", 12), ("s-5", 16),
        ("s-6", 20), ("s-7", 24), ("s-8", 32), ("s-9", 40), ("s-11", 64)
    ]
    private let radii: [(String, CGFloat)] = [
        ("r-1", 8), ("r-2", 12), ("r-3", 16), ("r-4", 20), ("r-5", 28)
    ]

    var body: some View {
        GalleryCard(kicker: "Spacing · Radius", title: "4pt rhythm") {
            VStack(alignment: .leading, spacing: 10) {
                ForEach(space, id: \.0) { name, value in
                    HStack(spacing: 14) {
                        Text(name).font(LumaFont.mono(11)).foregroundStyle(Color.lumaDim).frame(width: 44, alignment: .leading)
                        RoundedRectangle(cornerRadius: 3)
                            .fill(Color.lumaInTune)
                            .frame(width: value, height: 12)
                            .shadow(color: Color.lumaInTune.opacity(0.4), radius: 5)
                        Text("\(Int(value))").font(LumaFont.mono(11)).foregroundStyle(Color.lumaFaint)
                    }
                }
            }
            Divider().overlay(Color.lumaLine)
            HStack(alignment: .bottom, spacing: 14) {
                ForEach(radii, id: \.0) { name, value in
                    VStack(spacing: 6) {
                        UnevenRoundedRectangle(topLeadingRadius: value, topTrailingRadius: value)
                            .fill(Color.lumaSurface2)
                            .frame(width: 56, height: 56)
                            .overlay(
                                UnevenRoundedRectangle(topLeadingRadius: value, topTrailingRadius: value)
                                    .stroke(Color.lumaLine2, lineWidth: 1)
                            )
                        Text(name).font(LumaFont.mono(10)).foregroundStyle(Color.lumaDim)
                    }
                }
            }
        }
    }
}

// MARK: - Glow

struct GlowScaleCard: View {
    private let levels: [(BloomLevel, String, String)] = [
        (.l1, "bloom-1", "core"), (.l2, "bloom-2", "near"), (.l3, "bloom-3", "lock")
    ]

    var body: some View {
        GalleryCard(kicker: "Elevation", title: "Glow / Bloom — additive light") {
            Text("Depth comes from luminosity, not drop-shadows. Each level layers a tight core glow plus a soft outer bloom in the active hue.")
                .font(LumaFont.mono(10.5))
                .foregroundStyle(Color.lumaDim)
                .frame(maxWidth: .infinity, alignment: .leading)
            HStack(spacing: 30) {
                ForEach(levels, id: \.1) { level, name, label in
                    VStack(spacing: 12) {
                        RoundedRectangle(cornerRadius: Radius.r3, style: .continuous)
                            .fill(Color.lumaInTune)
                            .frame(width: 56, height: 56)
                            .bloom(level)
                        Text(name).font(LumaFont.mono(10)).foregroundStyle(Color.lumaDim)
                        Text(label).font(LumaFont.mono(9)).foregroundStyle(Color.lumaFaint)
                    }
                }
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, Space.s5)
            .lumaGlow(.lumaInTune)
            Divider().overlay(Color.lumaLine)
            VStack(spacing: 10) {
                Text("A")
                    .font(LumaFont.display(56))
                    .foregroundStyle(Color.lumaInTune)
                    .bloom(.text)
                Text(".bloom-text — the locked reward")
                    .font(LumaFont.mono(10)).foregroundStyle(Color.lumaDim)
            }
            .frame(maxWidth: .infinity)
            .lumaGlow(.lumaInTune)
        }
    }
}

// MARK: - Components

struct ComponentLibCard: View {
    @State private var mode: TargetMode = .auto
    @State private var source: InputKind = .di
    @State private var toneOn = false
    @State private var a4 = 440
    @State private var pick: Int? = 5

    var body: some View {
        GalleryCard(kicker: "Components", title: "Library") {
            block("Cents readout") {
                HStack(spacing: Space.s7) {
                    CentsReadout(cents: -6, state: .flat)
                    CentsReadout(cents: 4, state: .sharp)
                    CentsReadout(cents: 0, state: .tune)
                }
            }
            block("State line") {
                VStack(alignment: .leading, spacing: 12) {
                    StateLine(state: .flat); StateLine(state: .sharp)
                    StateLine(state: .tune); StateLine(state: .idle)
                }
            }
            block("Target chip · A4 · input · tone") {
                FlowControls {
                    TargetChip(mode: $mode)
                    A4Control(a4: $a4)
                    InputSource(source: $source)
                    ToneToggle(on: $toneOn)
                }
            }
            block("String selector") {
                StringRow(tuning: Tunings.guitar, activeIdx: $pick)
                    .frame(maxWidth: 380)
            }
            block("Oscilloscope · optional scope") {
                Oscilloscope(freq: 146.8, cents: -6, state: .flat, active: true)
                    .frame(height: 56)
                    .frame(maxWidth: 380)
            }
        }
    }

    @ViewBuilder
    private func block<Content: View>(_ label: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(label)
                .font(LumaFont.mono(9.5))
                .lumaTracking(Tracking.wide, size: 9.5)
                .textCase(.uppercase)
                .foregroundStyle(Color.lumaFaint)
            content()
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.bottom, Space.s2)
    }
}

/// A simple wrapping row for the control gallery (keeps chips on multiple lines
/// when space is tight).
private struct FlowControls<Content: View>: View {
    @ViewBuilder var content: Content
    var body: some View {
        ViewThatFits(in: .horizontal) {
            HStack(spacing: Space.s4) { content }
            VStack(alignment: .leading, spacing: Space.s4) { content }
        }
    }
}

#if DEBUG
#Preview("Gallery — dark") {
    DesignSystemGallery().preferredColorScheme(.dark)
}

#Preview("Gallery — light") {
    DesignSystemGallery().preferredColorScheme(.light)
}

#Preview("Gallery — accessibility XXXL") {
    DesignSystemGallery()
        .environment(\.dynamicTypeSize, .accessibility5)
        .preferredColorScheme(.dark)
}
#endif
