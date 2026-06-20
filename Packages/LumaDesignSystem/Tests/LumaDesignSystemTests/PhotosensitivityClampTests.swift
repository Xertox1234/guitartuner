import Testing
@testable import LumaDesignSystem

/// Verifies the WCAG 2.3.1 photosensitivity guard (C-4b, Lever C). The headline
/// test asserts the *compliance invariant* — the safety property — not merely the
/// clamp mechanics: for any incoming strobe rate, after the rate cap, the
/// off-pitch field either flickers ≤ 3/sec OR keeps its luminance swing ≤ 10% of
/// max. This is verified against the C-4a luminance model
/// (`StrobeMath.peakLuminanceSwing`), not an on-device flash measurement; the
/// rate-ceiling value is engineering judgement (see StrobeMath).
@Suite("WCAG 2.3.1 photosensitivity guard")
struct PhotosensitivityClampTests {

    @Test("rate cap + brightness guard satisfy the WCAG 2.3.1 invariant across a rate sweep")
    func complianceInvariant() {
        let eps = 1e-9
        for n in [13, 36] {                 // Aurora ribbons, Radial marks
            var r = -20.0
            while r <= 20.0 {               // cycles/sec — well beyond the worst real case
                let rate = StrobeMath.clampedStrobeRate(r)
                let flicker = Double(n) * abs(rate)
                let brightness = StrobeMath.photosensitivityBrightness(rateHz: rate, ribbonCount: n)
                let swing = StrobeMath.peakLuminanceSwing * brightness
                let rateSafe = flicker <= StrobeMath.flashSafeRegionHz + eps
                let swingSafe = swing <= StrobeMath.flashLuminanceFraction + eps
                #expect(rateSafe || swingSafe,
                        "n=\(n) r=\(r): flicker=\(flicker), swing=\(swing) — neither WCAG escape holds")
                r += 0.1
            }
        }
    }

    @Test("rate cap bounds magnitude and preserves sign (direction)")
    func rateCap() {
        #expect(StrobeMath.clampedStrobeRate(0) == 0)
        #expect(StrobeMath.clampedStrobeRate(2) == 2)                          // below cap → unchanged
        #expect(StrobeMath.clampedStrobeRate(50) == StrobeMath.maxStrobeRateHz)
        #expect(StrobeMath.clampedStrobeRate(-50) == -StrobeMath.maxStrobeRateHz)  // sign kept
    }

    @Test("full vividness at lock and near in-tune; a visible shimmer (never black) when far off")
    func brightnessEnvelope() {
        // At lock the eased rate is 0 → full brightness, so the in-tune bloom is untouched.
        #expect(StrobeMath.photosensitivityBrightness(rateHz: 0, ribbonCount: 13) == 1)
        // Slow drift (region flicker ≤ 2 Hz) stays fully vivid.
        #expect(StrobeMath.photosensitivityBrightness(rateHz: 2.0 / 13.0, ribbonCount: 13) == 1)
        // Fast off-pitch dims to the floor…
        #expect(StrobeMath.photosensitivityBrightness(rateHz: 4.0, ribbonCount: 13) == StrobeMath.shimmerFloor)
        // …but the floor is a visible shimmer, not darkness.
        #expect(StrobeMath.shimmerFloor > 0)
        #expect(StrobeMath.shimmerFloor < 1)
    }

    @Test("brightness is monotonically non-increasing as flicker rises")
    func monotonic() {
        var lastB = StrobeMath.photosensitivityBrightness(rateHz: 0, ribbonCount: 36)
        var r = 0.0
        while r <= 5.0 {
            let b = StrobeMath.photosensitivityBrightness(rateHz: r, ribbonCount: 36)
            #expect(b <= lastB + 1e-12)
            lastB = b
            r += 0.05
        }
    }
}
