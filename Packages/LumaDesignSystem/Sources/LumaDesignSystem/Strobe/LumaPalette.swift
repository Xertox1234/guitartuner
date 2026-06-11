import Foundation

/// User-selectable strobe colour palette. Changes the chromatic strobe slots
/// (`flat/flat2/sharp/sharp2/tune/tune2`); the app background and text stay
/// scheme-driven via `LumaTheme`.
///
/// Mirrors `StrobeStyle`: `String`-raw, `CaseIterable`, persisted via
/// `@AppStorage("strobePalette")`.
public enum LumaPalette: String, CaseIterable, Identifiable, Sendable {
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
}
