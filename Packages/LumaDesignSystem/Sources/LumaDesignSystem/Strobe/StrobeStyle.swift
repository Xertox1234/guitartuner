import Foundation

/// Which hero strobe to render. The decision is locked (DESIGN §2.2): **ship both,
/// user-selectable** — `aurora` (lateral light ribbons, default) and `radial`
/// (rotating phase ring). Persisted by the app in `@AppStorage("strobeStyle")`.
///
/// This is the *motion* preference only: when *Reduce Motion* is on, `StrobeField`
/// shows the still `ReducedGauge` regardless of the selected style (an equal, not a
/// downgrade) — so the choice re-applies automatically when motion is allowed again.
///
/// Both styles support the Metal renderer path (`StrobeField.useMetalRenderer`):
/// `.aurora` → `MetalStrobe`, `.radial` → `RadialMetalStrobe`.
public enum StrobeStyle: String, CaseIterable, Identifiable, Sendable {
    case aurora
    case radial

    public var id: String { rawValue }

    /// Display label for the Settings / lab picker.
    public var label: String {
        switch self {
        case .aurora: "Aurora"
        case .radial: "Radial"
        }
    }
}
