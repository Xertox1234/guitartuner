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

/// The strobe palette resolved for a colour scheme and an optional `LumaPalette`.
/// Chromatic slots (`flat/flat2/sharp/sharp2/tune/tune2`) come from the palette
/// table; `bg` and `ink` always follow the colour scheme so the app Theme stays
/// consistent regardless of palette choice.
struct StrobePalette {
    let flat, flat2, sharp, sharp2, tune, tune2, bg, ink: RGB

    static func resolve(_ scheme: ColorScheme, palette: LumaPalette = .aurora) -> StrobePalette {
        let (flat, flat2, sharp, sharp2, tune, tune2) = chroma(palette, scheme)
        let bg:  RGB = scheme == .light ? RGB(hex: 0xE7EAF1) : RGB(hex: 0x0A0B10)
        let ink: RGB = scheme == .light ? RGB(hex: 0x0D0F16) : RGB(hex: 0xEEF1F8)
        return StrobePalette(flat: flat, flat2: flat2, sharp: sharp, sharp2: sharp2,
                             tune: tune, tune2: tune2, bg: bg, ink: ink)
    }

    // Chromatic slots keyed by palette + scheme. Light variants are darker/more
    // saturated (Canvas uses .normal blend at 0.5 alpha); dark variants are
    // brighter (additive .plusLighter). flat2/sharp2 sit one step deeper on the
    // same hue ramp because the shader mixes them with flat/sharp at 0.35.
    private static func chroma(_ palette: LumaPalette, _ scheme: ColorScheme)
        -> (flat: RGB, flat2: RGB, sharp: RGB, sharp2: RGB, tune: RGB, tune2: RGB) {
        let light = scheme == .light
        switch palette {
        case .aurora:
            return light
                ? (RGB(hex: 0x2E6BFF), RGB(hex: 0x6B4DFF),
                   RGB(hex: 0xD9760F), RGB(hex: 0xDF4226),
                   RGB(hex: 0x07A07C), RGB(hex: 0x0A8E70))
                : (RGB(hex: 0x4D8BFF), RGB(hex: 0x8A6BFF),
                   RGB(hex: 0xFFA53C), RGB(hex: 0xFF6A4D),
                   RGB(hex: 0x28F0C0), RGB(hex: 0x16C8A0))
        case .amber:
            return light
                ? (RGB(hex: 0xB87333), RGB(hex: 0x8C4A1F),
                   RGB(hex: 0xE6A92B), RGB(hex: 0xD96A1A),
                   RGB(hex: 0xC9A227), RGB(hex: 0xA8821D))
                : (RGB(hex: 0xE89B4A), RGB(hex: 0xC76A2A),
                   RGB(hex: 0xFFD15C), RGB(hex: 0xFF8A33),
                   RGB(hex: 0xF5D547), RGB(hex: 0xD9B524))
        case .neon:
            return light
                ? (RGB(hex: 0x008CFF), RGB(hex: 0x0066CC),
                   RGB(hex: 0xE6007E), RGB(hex: 0xB80060),
                   RGB(hex: 0x66CC00), RGB(hex: 0x4DAA00))
                : (RGB(hex: 0x33CFFF), RGB(hex: 0x00A8FF),
                   RGB(hex: 0xFF3DA8), RGB(hex: 0xFF1480),
                   RGB(hex: 0xB6FF3D), RGB(hex: 0x8FE61A))
        case .forest:
            return light
                ? (RGB(hex: 0x2D6A6F), RGB(hex: 0x1F4A4E),
                   RGB(hex: 0xB55A2E), RGB(hex: 0x8A3F1F),
                   RGB(hex: 0x6B8E23), RGB(hex: 0x4F6B19))
                : (RGB(hex: 0x4FA8AE), RGB(hex: 0x357B82),
                   RGB(hex: 0xE8884A), RGB(hex: 0xC4602C),
                   RGB(hex: 0xA8C66C), RGB(hex: 0x88A554))
        case .crimson:
            return light
                ? (RGB(hex: 0x6E3FA8), RGB(hex: 0x4B2380),
                   RGB(hex: 0xC1264D), RGB(hex: 0x8A0E2E),
                   RGB(hex: 0x1E8E5A), RGB(hex: 0x126E45))
                : (RGB(hex: 0xA070E0), RGB(hex: 0x7A4FC2),
                   RGB(hex: 0xFF4D70), RGB(hex: 0xE02853),
                   RGB(hex: 0x3DD992), RGB(hex: 0x20B074))
        }
    }
}
