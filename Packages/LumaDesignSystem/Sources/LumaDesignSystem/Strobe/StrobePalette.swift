import SwiftUI

/// RGB triple in 0...1 for additive strobe blending — the `Canvas` needs colour
/// component access that SwiftUI `Color` doesn't expose. Values mirror
/// `ds-tokens.css` (the strobe reads the same palette as `readPalette()` in
/// `strobe-aurora.jsx`).
struct RGB: Equatable {
    var r, g, b: Double

    init(_ r: Double, _ g: Double, _ b: Double) {
        self.r = r; self.g = g; self.b = b
    }

    init(hex: UInt32) {
        r = Double((hex >> 16) & 0xFF) / 255
        g = Double((hex >> 8) & 0xFF) / 255
        b = Double(hex & 0xFF) / 255
    }
}

/// Linear interpolate two colours (`t` 0→a, 1→b).
func mix(_ a: RGB, _ b: RGB, _ t: Double) -> RGB {
    RGB(a.r + (b.r - a.r) * t,
        a.g + (b.g - a.g) * t,
        a.b + (b.b - a.b) * t)
}

extension Color {
    init(_ rgb: RGB, opacity: Double) {
        self.init(.sRGB, red: rgb.r, green: rgb.g, blue: rgb.b, opacity: opacity)
    }
}

/// The strobe palette resolved for a colour scheme (dark default). Hex values
/// from `ds-tokens.css`.
struct StrobePalette {
    let flat, flat2, sharp, sharp2, tune, tune2, bg, ink: RGB

    static func resolve(_ scheme: ColorScheme) -> StrobePalette {
        scheme == .light
        ? StrobePalette(flat:  RGB(hex: 0x2E6BFF), flat2: RGB(hex: 0x6B4DFF),
                        sharp: RGB(hex: 0xD9760F), sharp2: RGB(hex: 0xDF4226),
                        tune:  RGB(hex: 0x07A07C), tune2: RGB(hex: 0x0A8E70),
                        bg:    RGB(hex: 0xE7EAF1), ink:   RGB(hex: 0x0D0F16))
        : StrobePalette(flat:  RGB(hex: 0x4D8BFF), flat2: RGB(hex: 0x8A6BFF),
                        sharp: RGB(hex: 0xFFA53C), sharp2: RGB(hex: 0xFF6A4D),
                        tune:  RGB(hex: 0x28F0C0), tune2: RGB(hex: 0x16C8A0),
                        bg:    RGB(hex: 0x0A0B10), ink:   RGB(hex: 0xEEF1F8))
    }
}
