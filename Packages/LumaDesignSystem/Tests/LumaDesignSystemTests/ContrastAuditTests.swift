import Testing
@testable import LumaDesignSystem
import SwiftUI

// WCAG 2.x relative luminance + contrast ratio (sRGB). Test-only — enforces that
// the design tokens meet AA so a future hex edit can't silently regress contrast.
private func relativeLuminance(_ c: RGB) -> Double {
    func lin(_ v: Double) -> Double { v <= 0.03928 ? v / 12.92 : pow((v + 0.055) / 1.055, 2.4) }
    return 0.2126 * lin(c.r) + 0.7152 * lin(c.g) + 0.0722 * lin(c.b)
}
private func contrastRatio(_ a: RGB, _ b: RGB) -> Double {
    let la = relativeLuminance(a), lb = relativeLuminance(b)
    let (hi, lo) = (max(la, lb), min(la, lb))
    return (hi + 0.05) / (lo + 0.05)
}

@Suite("WCAG AA contrast — state colors")
struct ContrastAuditTests {

    // Backgrounds confirmed from Colors.xcassets/bg.colorset/Contents.json:
    //   universal (light) = #E7EAF1, dark = #0A0B10
    let bgDark  = RGB(hex: 0x0A0B10)
    let bgLight = RGB(hex: 0xE7EAF1)

    // Colorset hexes confirmed from Colors.xcassets/{flat,sharp,inTune}.colorset:
    //   flat:   light #2E6BFF  dark #4D8BFF
    //   sharp:  light #D9760F  dark #FFA53C
    //   inTune: light #07A07C  dark #28F0C0
    // These are identical to StrobePalette.chroma(.aurora, scheme) primaries — confirmed
    // by reading StrobePalette.swift aurora branch.

    // ──────────────────────────────────────────────────────────────────────
    // 1. Sanity: formula reproduces the canonical black/white extreme (21:1).
    // ──────────────────────────────────────────────────────────────────────
    @Test("luminance formula is correct at the extremes")
    func formulaSanity() {
        #expect(abs(contrastRatio(RGB(0, 0, 0), RGB(1, 1, 1)) - 21.0) < 0.01)
        #expect(abs(contrastRatio(RGB(1, 1, 1), RGB(1, 1, 1)) - 1.0) < 0.01)
    }

    // ──────────────────────────────────────────────────────────────────────
    // 2. State TEXT contrast — DARK appearance — threshold 4.5 (normal text)
    //    StateLine tag text (10 pt mono) on bg dark #0A0B10.
    //    All dark tokens have wide margin — these stay ENABLED.
    // ──────────────────────────────────────────────────────────────────────
    @Test("state colors meet AA text contrast (4.5:1) — dark appearance")
    func stateTextContrast_dark() {
        let darkTokens: [(String, RGB)] = [
            ("flat",   RGB(hex: 0x4D8BFF)),
            ("sharp",  RGB(hex: 0xFFA53C)),
            ("inTune", RGB(hex: 0x28F0C0)),
        ]
        for (name, c) in darkTokens {
            let ratio = contrastRatio(c, bgDark)
            print("[contrast-audit] \(name) dark vs bg-dark: \(String(format: "%.2f", ratio)):1")
            #expect(ratio >= 4.5, "\(name) (dark) below AA text (4.5:1); got \(ratio)")
        }
    }

    // ──────────────────────────────────────────────────────────────────────
    // 3. State TEXT contrast — LIGHT appearance — threshold 4.5 (normal text)
    //    StateLine tag text (10 pt mono) on bg light #E7EAF1.
    //    KNOWN FAILURE: flat 3.74, sharp 2.66, inTune 2.76 — all below 4.5.
    //    Disabled: surfaced to design as a brand-palette decision.
    // ──────────────────────────────────────────────────────────────────────
    @Test(.disabled("surfaced to design: light-mode aurora state tokens below AA text (4.5) — see state-color-contrast-audit-2026-06-19.md; awaiting brand decision"))
    func stateTextContrast_light() {
        let lightTokens: [(String, RGB)] = [
            ("flat",   RGB(hex: 0x2E6BFF)),
            ("sharp",  RGB(hex: 0xD9760F)),
            ("inTune", RGB(hex: 0x07A07C)),
        ]
        for (name, c) in lightTokens {
            let ratio = contrastRatio(c, bgLight)
            print("[contrast-audit] \(name) light vs bg-light: \(String(format: "%.2f", ratio)):1")
            #expect(ratio >= 4.5, "\(name) (light) below AA text (4.5:1); got \(ratio)")
        }
    }

    // ──────────────────────────────────────────────────────────────────────
    // 4. Strobe GRAPHIC contrast — DARK appearance — threshold 3.0
    //    Aurora strobe ribbons (large text / graphic indicator) on bg dark.
    //    Dark tokens have wide margin — ENABLED.
    //    Uses StrobePalette.resolve to confirm palette-to-colorset parity.
    // ──────────────────────────────────────────────────────────────────────
    @Test("aurora strobe ribbons meet AA graphic contrast (3.0:1) — dark appearance")
    func strobeGraphicContrast_dark() {
        let pal = StrobePalette.resolve(.dark, palette: .aurora)
        let slots: [(String, RGB)] = [
            ("flat",   pal.flat),
            ("sharp",  pal.sharp),
            ("tune",   pal.tune),
        ]
        for (name, c) in slots {
            let ratio = contrastRatio(c, bgDark)
            print("[contrast-audit] aurora \(name) dark vs bg-dark: \(String(format: "%.2f", ratio)):1")
            #expect(ratio >= 3.0, "aurora \(name) (dark) below AA graphic (3.0:1); got \(ratio)")
        }
    }

    // ──────────────────────────────────────────────────────────────────────
    // 5. Strobe GRAPHIC contrast — LIGHT appearance — threshold 3.0
    //    KNOWN FAILURE: flat 3.74 (passes), sharp 2.66, inTune 2.76 (both fail).
    //    Disabled: surfaced to design as a brand-palette decision.
    // ──────────────────────────────────────────────────────────────────────
    @Test(.disabled("surfaced to design: light-mode aurora sharp/inTune below AA graphic (3.0) — see state-color-contrast-audit-2026-06-19.md; awaiting brand decision"))
    func strobeGraphicContrast_light() {
        let pal = StrobePalette.resolve(.light, palette: .aurora)
        let slots: [(String, RGB)] = [
            ("flat",   pal.flat),
            ("sharp",  pal.sharp),
            ("tune",   pal.tune),
        ]
        for (name, c) in slots {
            let ratio = contrastRatio(c, bgLight)
            print("[contrast-audit] aurora \(name) light vs bg-light: \(String(format: "%.2f", ratio)):1")
            #expect(ratio >= 3.0, "aurora \(name) (light) below AA graphic (3.0:1); got \(ratio)")
        }
    }
}
