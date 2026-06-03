import XCTest
@testable import LumaDesignSystem

/// Verifies the Metal hero path's colour blend (`StrobeShaderColors`) matches the
/// Aurora intent: flat leans blue, sharp leans warm, and everything collapses to
/// the sacred mint at lock.
final class StrobeShaderColorsTests: XCTestCase {
    private let pal = StrobePalette.resolve(.dark)

    func testLockedCollapsesToMint() {
        // At full lock the ribbon colour is pure mint regardless of which side we
        // came from (mix(side, tune, 1) == tune).
        for cents in [-40.0, -3.0, 5.0, 30.0] {
            let main = StrobeShaderColors.main(cents: cents, prox: 0, lock: 1, pal: pal)
            XCTAssertEqual(main.r, pal.tune.r, accuracy: 1e-9)
            XCTAssertEqual(main.g, pal.tune.g, accuracy: 1e-9)
            XCTAssertEqual(main.b, pal.tune.b, accuracy: 1e-9)
        }
    }

    func testFlatLeansBlueSharpLeansWarm() {
        // Far from pitch (no proximity, no lock) the side colour dominates.
        let flat = StrobeShaderColors.main(cents: -45, prox: 0, lock: 0, pal: pal)
        XCTAssertGreaterThan(flat.b, flat.r)          // blue-violet
        let sharp = StrobeShaderColors.main(cents: 45, prox: 0, lock: 0, pal: pal)
        XCTAssertGreaterThan(sharp.r, sharp.b)        // amber-red
    }

    func testColumnIsIdentityWhenUnlocked() {
        let main = StrobeShaderColors.main(cents: -10, prox: 0.4, lock: 0, pal: pal)
        let col = StrobeShaderColors.column(main: main, lock: 0, pal: pal)
        XCTAssertEqual(col.r, main.r, accuracy: 1e-9)
        XCTAssertEqual(col.g, main.g, accuracy: 1e-9)
        XCTAssertEqual(col.b, main.b, accuracy: 1e-9)
    }

    func testColumnPullsToMintAtLock() {
        let main = StrobeShaderColors.main(cents: -10, prox: 0.4, lock: 1, pal: pal)
        let col = StrobeShaderColors.column(main: main, lock: 1, pal: pal)
        XCTAssertEqual(col.g, pal.tune.g, accuracy: 1e-9)
    }

    func testSimd4PacksComponents() {
        let v = RGB(0.25, 0.5, 0.75).simd4
        XCTAssertEqual(v.x, 0.25, accuracy: 1e-6)
        XCTAssertEqual(v.y, 0.5, accuracy: 1e-6)
        XCTAssertEqual(v.z, 0.75, accuracy: 1e-6)
        XCTAssertEqual(v.w, 1.0, accuracy: 1e-6)
    }
}
