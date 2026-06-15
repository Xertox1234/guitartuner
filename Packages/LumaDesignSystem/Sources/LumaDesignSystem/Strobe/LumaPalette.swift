import SwiftUI

/// User-selectable strobe colour palette. Changes the chromatic strobe slots
/// (`flat/flat2/sharp/sharp2/tune/tune2`); the app background and text stay
/// scheme-driven via `LumaTheme`.
///
/// Mirrors `StrobeStyle`: `String`-raw, `CaseIterable`, persisted via
/// `@AppStorage("strobePalette")`.
public enum LumaPalette: String, CaseIterable, Codable, Identifiable, Sendable {
    case aurora
    case amber
    case neon
    case forest
    case crimson

    public var id: String { rawValue }

    public var label: String {
        switch self {
        case .aurora:  "Aurora"
        case .amber:   "Amber"
        case .neon:    "Neon"
        case .forest:  "Forest"
        case .crimson: "Crimson"
        }
    }

    /// Representative UI color for this palette — use for chips, labels, and
    /// card accents. Not the strobe render color (see `StrobePalette`).
    public var color: Color {
        switch self {
        case .aurora:  .lumaInTune
        case .amber:   Color(hue: 0.1,  saturation: 0.8, brightness: 0.9)
        case .neon:    Color(hue: 0.75, saturation: 0.8, brightness: 0.9)
        case .forest:  Color(hue: 0.35, saturation: 0.7, brightness: 0.7)
        case .crimson: Color(hue: 0.0,  saturation: 0.8, brightness: 0.85)
        }
    }
}
