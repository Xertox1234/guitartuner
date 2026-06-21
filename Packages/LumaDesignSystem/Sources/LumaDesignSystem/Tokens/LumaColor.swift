import SwiftUI

/// LUMA colour tokens, backed by the `Colors.xcassets` catalog in this package.
///
/// Each token is a colour set with an **Any (light)** + **Dark** appearance, so
/// the system resolves the active theme. Values come straight from
/// `docs/design_reference/ds-tokens.css` (`DESIGN_SYSTEM.md` is the source of truth),
/// with one deliberate exception: the **light** `flat`/`sharp`/`inTune` state tokens
/// were darkened from the reference hexes to meet WCAG AA text contrast (4.5:1) on the
/// light background — see `docs/solutions/accessibility/state-color-contrast-audit-2026-06-19.md`.
///
/// Use either the enum (handy for enumerating tokens in the gallery) or the
/// `Color.luma*` conveniences (idiomatic in views):
/// ```swift
/// Text("LUMA").foregroundStyle(Color.lumaInk)
/// ForEach(LumaColor.allCases) { swatch($0.color) }
/// ```
public enum LumaColor: String, CaseIterable, Identifiable, Sendable {
    // Neutrals
    case bg, bgGrad, surface, surface2, surface3
    case ink, dim, faint, line, line2
    // Signal (error coding — never colour alone; paired with sign + motion)
    case flat, flat2, sharp, sharp2
    // Sacred — only the locked / in-tune state
    case inTune, inTune2, brandGlow
    case scrim

    public var id: String { rawValue }

    /// The resolved SwiftUI colour for the active appearance.
    public var color: Color { Color(rawValue, bundle: .module) }

    /// Human label for gallery swatches.
    public var label: String {
        switch self {
        case .bg: "bg"
        case .bgGrad: "bg-grad"
        case .surface: "surface"
        case .surface2: "surface-2"
        case .surface3: "surface-3"
        case .ink: "ink"
        case .dim: "dim"
        case .faint: "faint"
        case .line: "line"
        case .line2: "line-2"
        case .flat: "flat"
        case .flat2: "flat · violet"
        case .sharp: "sharp"
        case .sharp2: "sharp · coral"
        case .inTune: "in-tune · SACRED"
        case .inTune2: "in-tune deep"
        case .brandGlow: "brand-glow"
        case .scrim: "scrim"
        }
    }
}

public extension Color {
    static let lumaBg = LumaColor.bg.color
    static let lumaBgGrad = LumaColor.bgGrad.color
    static let lumaSurface = LumaColor.surface.color
    static let lumaSurface2 = LumaColor.surface2.color
    static let lumaSurface3 = LumaColor.surface3.color
    static let lumaInk = LumaColor.ink.color
    static let lumaDim = LumaColor.dim.color
    static let lumaFaint = LumaColor.faint.color
    static let lumaLine = LumaColor.line.color
    static let lumaLine2 = LumaColor.line2.color
    static let lumaFlat = LumaColor.flat.color
    static let lumaFlat2 = LumaColor.flat2.color
    static let lumaSharp = LumaColor.sharp.color
    static let lumaSharp2 = LumaColor.sharp2.color
    static let lumaInTune = LumaColor.inTune.color
    static let lumaInTune2 = LumaColor.inTune2.color
    static let lumaBrandGlow = LumaColor.brandGlow.color
    static let lumaScrim = LumaColor.scrim.color
}
