import SwiftUI

/// Letter-spacing tokens. CSS expresses tracking in `em` (relative to font
/// size); SwiftUI `.tracking(_:)` takes points, so we resolve `em × size`.
/// Mirrors `--tracking-wide` (0.18em) and `--tracking-mono` (0.04em).
public enum Tracking {
    public static let wide: CGFloat = 0.18    // uppercase eyebrows
    public static let mono: CGFloat = 0.04    // tabular mono default
    public static let chip: CGFloat = 0.12    // chip / edge-button labels
    public static let chipWide: CGFloat = 0.14 // target chip / freq line
    public static let tag: CGFloat = 0.16     // state-line tag, wordmark

    /// Resolve an `em` tracking value to points for a given font size.
    public static func points(_ em: CGFloat, size: CGFloat) -> CGFloat { em * size }
}

public extension View {
    /// Apply LUMA tracking expressed in `em` for the given font `size`.
    func lumaTracking(_ em: CGFloat, size: CGFloat) -> some View {
        tracking(Tracking.points(em, size: size))
    }
}
