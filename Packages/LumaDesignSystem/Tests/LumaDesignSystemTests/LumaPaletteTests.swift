import Testing
@testable import LumaDesignSystem
import SwiftUI

@Suite("LumaPalette")
struct LumaPaletteTests {
    // The no-arg resolve call must continue to return the Aurora palette so
    // existing callers are unaffected.
    @Test func defaultPaletteMatchesAurora() {
        let noArg = StrobePalette.resolve(.dark)
        let explicit = StrobePalette.resolve(.dark, palette: .aurora)
        #expect(noArg.flat  == explicit.flat)
        #expect(noArg.flat2 == explicit.flat2)
        #expect(noArg.sharp  == explicit.sharp)
        #expect(noArg.sharp2 == explicit.sharp2)
        #expect(noArg.tune  == explicit.tune)
        #expect(noArg.tune2 == explicit.tune2)
        #expect(noArg.bg    == explicit.bg)
        #expect(noArg.ink   == explicit.ink)
    }

    // bg and ink must be identical across all palettes for the same scheme —
    // palette only changes chromatic slots, never the app surface.
    @Test func bgAndInkArePaletteAgnostic() throws {
        for scheme in [ColorScheme.light, ColorScheme.dark] {
            let aurora = StrobePalette.resolve(scheme, palette: .aurora)
            for palette in LumaPalette.allCases where palette != .aurora {
                let p = StrobePalette.resolve(scheme, palette: palette)
                #expect(p.bg  == aurora.bg,  "bg differs for \(palette) in \(scheme)")
                #expect(p.ink == aurora.ink, "ink differs for \(palette) in \(scheme)")
            }
        }
    }

    // Every non-Aurora palette must differ from Aurora on at least one chromatic
    // slot, guarding against copy-paste errors in the hex table.
    @Test func allPalettesProduceDistinctChroma() {
        for scheme in [ColorScheme.light, ColorScheme.dark] {
            let aurora = StrobePalette.resolve(scheme, palette: .aurora)
            for palette in LumaPalette.allCases where palette != .aurora {
                let p = StrobePalette.resolve(scheme, palette: palette)
                let distinct = p.flat  != aurora.flat  ||
                               p.flat2 != aurora.flat2 ||
                               p.sharp  != aurora.sharp  ||
                               p.sharp2 != aurora.sharp2 ||
                               p.tune  != aurora.tune  ||
                               p.tune2 != aurora.tune2
                #expect(distinct, "\(palette) in \(scheme) is identical to Aurora — check hex table")
            }
        }
    }

    // Sanity-check a couple of representative literals so a future hex-table
    // shuffle gets caught at CI time.
    @Test func amberDarkFlatIsGold() {
        let pal = StrobePalette.resolve(.dark, palette: .amber)
        #expect(pal.flat == RGB(hex: 0xE89B4A))
    }

    @Test func neonDarkSharpIsMagenta() {
        let pal = StrobePalette.resolve(.dark, palette: .neon)
        #expect(pal.sharp == RGB(hex: 0xFF3DA8))
    }

    @Test func crimsonDarkTuneIsEmerald() {
        let pal = StrobePalette.resolve(.dark, palette: .crimson)
        #expect(pal.tune == RGB(hex: 0x3DD992))
    }
}
