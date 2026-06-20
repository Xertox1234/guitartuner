import Foundation

/// Single source of truth for the Reduce Transparency policy. Additive bloom and
/// the radial glow washes are *translucency*; when `accessibilityReduceTransparency`
/// is on, Apple HIG asks apps to drop blur/translucency in favour of solid
/// treatments. Every translucent layer routes its opacity through here so the
/// behaviour is uniform and unit-testable (the modifiers stay thin).
///
/// Kept free of SwiftUI so it's testable headlessly.
enum Translucency {
    /// The opacity a translucent layer should use. Collapses to fully
    /// transparent under Reduce Transparency (the opaque base treatment beneath
    /// — solid text, the solid canvas gradient — preserves legibility).
    static func attenuated(_ base: Double, reduceTransparency: Bool) -> Double {
        reduceTransparency ? 0 : base
    }
}
