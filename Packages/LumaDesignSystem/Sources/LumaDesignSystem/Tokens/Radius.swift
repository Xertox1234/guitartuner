import CoreGraphics

/// LUMA corner radii: `8 · 12 · 16 · 20 · 28 · 40 · full`.
/// Mirrors the `--r-*` tokens in `ds-tokens.css`. Use `Radius.full` with a
/// `Capsule()` for pill shapes.
public enum Radius {
    public static let r1: CGFloat = 8
    public static let r2: CGFloat = 12
    public static let r3: CGFloat = 16
    public static let r4: CGFloat = 20
    public static let r5: CGFloat = 28
    public static let r6: CGFloat = 40
    public static let full: CGFloat = 9999
}
