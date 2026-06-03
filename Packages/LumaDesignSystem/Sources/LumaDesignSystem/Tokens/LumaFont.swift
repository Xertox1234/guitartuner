import SwiftUI
#if canImport(UIKit)
import UIKit
#elseif canImport(AppKit)
import AppKit
#endif

/// LUMA type scale + families.
///
/// - **Display / note / wordmark** → Chakra Petch 600 (hero note at 168pt)
/// - **Numerals / labels / mono** → JetBrains Mono, tabular figures
/// - **UI / body** → system (SF), Dynamic-Type feel
///
/// Custom faces are used when registered (see `LumaFonts`); otherwise we fall
/// back to SF Pro Display / SF Mono so the app always renders. Values mirror
/// `docs/design_reference/ds-tokens.css`.
public enum LumaFont {

    /// Type scale in points: `11 · 12 · 13 · 15 · 17 · 20 · 24 · 32 · 44 · 56 · 72 · 168`.
    public enum Size {
        public static let micro: CGFloat = 11   // eyebrow / freq line
        public static let cap: CGFloat = 12      // chips
        public static let label: CGFloat = 13    // wordmark / labels
        public static let body: CGFloat = 15     // state line
        public static let lg: CGFloat = 17
        public static let xl: CGFloat = 20
        public static let xl2: CGFloat = 24      // card titles
        public static let xl3: CGFloat = 32
        public static let xl4: CGFloat = 44
        public static let num: CGFloat = 56      // big cents / Hz readouts
        public static let xl5: CGFloat = 72
        public static let note: CGFloat = 168     // the hero note name
    }

    public static let displayFamily = "Chakra Petch"
    public static let monoFamily = "JetBrains Mono"

    // MARK: Builders

    /// Display face (Chakra Petch), falling back to SF Pro Display.
    public static func display(_ size: CGFloat, weight: Font.Weight = .semibold) -> Font {
        if isAvailable(displayFamily) {
            return .custom(displayFamily, size: size).weight(weight)
        }
        return .system(size: size, weight: weight, design: .default)
    }

    /// Mono face (JetBrains Mono) with tabular digits, falling back to SF Mono.
    public static func mono(_ size: CGFloat, weight: Font.Weight = .regular) -> Font {
        let base: Font = isAvailable(monoFamily)
            ? .custom(monoFamily, size: size).weight(weight)
            : .system(size: size, weight: weight, design: .monospaced)
        return base.monospacedDigit()
    }

    /// System UI face for body/labels (full Dynamic Type + localization).
    public static func ui(_ size: CGFloat, weight: Font.Weight = .regular) -> Font {
        .system(size: size, weight: weight, design: .default)
    }

    // MARK: Availability

    private static func isAvailable(_ family: String) -> Bool {
        #if canImport(UIKit)
        return UIFont(name: family, size: 12) != nil
        #elseif canImport(AppKit)
        return NSFont(name: family, size: 12) != nil
        #else
        return false
        #endif
    }
}

public extension Font {
    /// The hero note name — Chakra Petch 600 @ 168.
    static var lumaNote: Font { LumaFont.display(LumaFont.Size.note) }
    /// Card / section titles — Chakra Petch 600 @ 24.
    static var lumaTitle: Font { LumaFont.display(LumaFont.Size.xl2) }
    /// The wordmark / small display labels @ 13.
    static var lumaWordmark: Font { LumaFont.display(LumaFont.Size.label) }
    /// Big signed cents readout — JetBrains Mono 500 @ 30.
    static var lumaCents: Font { LumaFont.mono(30, weight: .medium) }
    /// State-line hint — system 500 @ 15.
    static var lumaStateHint: Font { LumaFont.ui(LumaFont.Size.body, weight: .medium) }
    /// Freq line / chip mono @ 11.
    static var lumaMicroMono: Font { LumaFont.mono(LumaFont.Size.micro) }
}
