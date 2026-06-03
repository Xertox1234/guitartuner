import Foundation

/// Pure logic backing the macOS **menu-bar micro-strobe** (EXPERIENCE §8).
///
/// The visual lives in the app target (a `MenuBarExtra` reusing `StrobeField`),
/// but the one decision worth pinning down — *what the bar shows at a glance* — is
/// kept here, SwiftUI-free and unit-tested, like `StrobeMath` / `ScopeMath`.
public enum MenuBarStrobe {
    /// The short caption beside the menu-bar tuning-fork glyph.
    ///
    /// The bar stays **quiet at rest** (empty caption when we're not listening or
    /// there's no signal) so it doesn't nag; once there's a live reading it shows the
    /// note, so an in-tune string reads from the corner of the eye without opening the
    /// popover. Colour is never the only cue — the note text carries the meaning.
    public static func caption(note: String, running: Bool, state: TunerVisualState) -> String {
        guard running, state != .idle else { return "" }
        return note
    }
}
