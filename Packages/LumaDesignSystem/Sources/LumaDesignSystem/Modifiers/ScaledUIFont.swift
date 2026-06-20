import SwiftUI

/// A system (SF) font at a fixed point size that scales with Dynamic Type,
/// anchored to a text style. Use for chrome / settings / informational text:
/// `LumaFont.ui(_:)` returns a *fixed* `Font` (a system font cannot carry
/// `relativeTo:`), so scaling must happen at the view via `@ScaledMetric`.
public struct ScaledUIFont: ViewModifier {
    @ScaledMetric private var size: CGFloat
    private let weight: Font.Weight

    public init(size: CGFloat, weight: Font.Weight, relativeTo textStyle: Font.TextStyle) {
        self._size = ScaledMetric(wrappedValue: size, relativeTo: textStyle)
        self.weight = weight
    }

    public func body(content: Content) -> some View {
        content.font(.system(size: size, weight: weight))
    }
}

public extension View {
    /// Apply a Dynamic-Type-scaling system font (chrome / informational text).
    func lumaUIFont(_ size: CGFloat,
                    weight: Font.Weight = .regular,
                    relativeTo textStyle: Font.TextStyle = .body) -> some View {
        modifier(ScaledUIFont(size: size, weight: weight, relativeTo: textStyle))
    }
}
