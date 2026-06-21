import Testing
import Foundation
@testable import LumaDesignSystem

// WCAG 2.x relative luminance + contrast ratio (sRGB). Test-only. The strobe tests
// resolve live from `StrobePalette.resolve()`, so they catch any palette hex regression.
// The colorset text tests assert fixed reference hexes mirrored by hand from the
// `*.colorset` assets — they pin the audited values, not the live asset bytes.
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
    //   flat:   light #285EE2  dark #4D8BFF
    //   sharp:  light #9F5508  dark #FFA53C
    //   inTune: light #04775B  dark #28F0C0
    // The DARK colorset hexes are identical to StrobePalette.chroma(.aurora, .dark)
    // primaries. The LIGHT hexes intentionally DIVERGE (two-tier light palette,
    // 2026-06-21): the colorset tokens are the text-safe values the small StateLine
    // tag *text* uses (4.5:1), darker than the strobe ribbon values
    // (StrobePalette aurora light: flat #2E6BFF, sharp #C66B0D, tune #069573, graphic
    // 3:1). See docs/solutions/accessibility/state-color-contrast-audit-2026-06-19.md.

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
            #expect(ratio >= 4.5, "\(name) (dark) below AA text (4.5:1); got \(ratio)")
        }
    }

    // ──────────────────────────────────────────────────────────────────────
    // 3. State TEXT contrast — LIGHT appearance — threshold 4.5 (normal text)
    //    StateLine tag text (10 pt mono) on bg light #E7EAF1.
    //    Two-tier fix (2026-06-21): the text-safe colorset tokens were darkened to
    //    clear 4.5:1 — flat 4.60, sharp 4.62, inTune 4.59. The vivid strobe ribbons
    //    stay lighter (graphic 3:1, asserted separately below). StateLine colours the
    //    in-tune tag from `state.glow` (the inTune colorset), not the palette glow,
    //    so this colorset value is what actually renders.
    // ──────────────────────────────────────────────────────────────────────
    @Test("state colors meet AA text contrast (4.5:1) — light appearance")
    func stateTextContrast_light() {
        let lightTokens: [(String, RGB)] = [
            ("flat",   RGB(hex: 0x285EE2)),
            ("sharp",  RGB(hex: 0x9F5508)),
            ("inTune", RGB(hex: 0x04775B)),
        ]
        for (name, c) in lightTokens {
            let ratio = contrastRatio(c, bgLight)
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
            #expect(ratio >= 3.0, "aurora \(name) (dark) below AA graphic (3.0:1); got \(ratio)")
        }
    }

    // ──────────────────────────────────────────────────────────────────────
    // 5. Strobe GRAPHIC contrast — LIGHT appearance — threshold 3.0 — ALL palettes
    //    The rendered ribbon set per palette is the three pure primaries
    //    (flat/sharp/tune — ReducedGauge at opacity 1, the in-tune glow) plus the
    //    two side ribbons mix(flat,flat2,0.35) and mix(sharp,sharp2,0.35).
    //    flat2/sharp2 never render alone; tune2 is never rendered. Gating these five is
    //    COMPLETE: sRGB→linear is convex, so contrast(mix) ≥ min(contrast(endpoints));
    //    every other rendered mix (e.g. the in-tune mix(side, tune, …)) is ≥ 3:1 too.
    //    Two-tier fix: aurora (2026-06-21); amber sharp/sharp2/tune and neon flat/tune
    //    nudged to clear 3:1 while staying vivid (2026-06-21 follow-up). forest/crimson
    //    already passed. Resolves live from StrobePalette, tracking actual ribbon hexes.
    // ──────────────────────────────────────────────────────────────────────
    @Test("strobe ribbons meet AA graphic contrast (3.0:1) — light appearance, all palettes")
    func strobeGraphicContrast_light() {
        for palette in LumaPalette.allCases {
            let pal = StrobePalette.resolve(.light, palette: palette)
            let rendered: [(String, RGB)] = [
                ("flat",     pal.flat),
                ("sharp",    pal.sharp),
                ("tune",     pal.tune),
                ("flatMix",  mix(pal.flat,  pal.flat2,  0.35)),
                ("sharpMix", mix(pal.sharp, pal.sharp2, 0.35)),
            ]
            for (name, c) in rendered {
                let ratio = contrastRatio(c, bgLight)
                #expect(ratio >= 3.0,
                        "\(palette.rawValue) \(name) (light) below AA graphic (3.0:1); got \(ratio)")
            }
        }
    }
}
