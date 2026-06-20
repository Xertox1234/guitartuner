import Foundation

/// Pure strobe math ported from `strobe-aurora.jsx` / `strobe-core.jsx`. Kept
/// free of SwiftUI so it's unit-testable.
enum StrobeMath {
    /// Proximity 0...1 (1 = on pitch) — drives ribbon convergence and the blend
    /// toward mint. `max(0, 1 − |cents|/18)`.
    static func proximity(cents: Double) -> Double {
        max(0, 1 - abs(cents) / 18)
    }

    /// Lateral scroll speed (fraction of width per second). Proportional to the
    /// signed error, eased to zero at lock. Mirrors `(sign·absErr)·0.0009` per
    /// `dt·60` frame in the export.
    static func scrollSpeed(cents: Double, lock: Double) -> Double {
        cents * 0.0009 * 60 * (1 - lock)
    }

    /// Ribbon half-span as a fraction of width — compresses toward the centre
    /// column as we approach/lock. `0.5 − 0.34·max(prox, lock)`.
    static func spread(prox: Double, lock: Double) -> Double {
        0.5 - 0.34 * max(prox, lock)
    }

    // MARK: Radial phase ring (Concept B)

    /// Ring rotation speed (radians/sec) — the Radial analogue of `scrollSpeed`.
    /// Proportional to the signed error (sharp → CW, flat → CCW), eased to zero at
    /// lock. Mirrors `(sign·absErr)·0.010` per `dt·60` frame in `strobe-radial.jsx`,
    /// i.e. `cents·0.010·60·(1 − lock)`.
    static func ringSpeed(cents: Double, lock: Double) -> Double {
        cents * 0.010 * 60 * (1 - lock)
    }

    /// Per-mark brightness envelope (0.35…1) at ring angle `a` (radians). A `cos`
    /// sweep that peaks at the top of the ring (`a = −π/2`) so the leading edge
    /// reads as motion. Mirrors `0.35 + 0.65·((phase+1)/2)^1.5` in `strobe-radial.jsx`.
    static func markEnvelope(angle a: Double) -> Double {
        let phase = cos(a + .pi / 2)        // peaks at the top (a = −π/2); == −sin(a)
        return 0.35 + 0.65 * pow((phase + 1) / 2, 1.5)
    }

    // MARK: Reduced-motion gauge

    /// Degrees swept either side of centre.
    static let gaugeSpan: Double = 122

    /// cents (−50…50) → dial angle in degrees (0 = up), clamped to ±span.
    static func gaugeAngle(cents: Double) -> Double {
        max(-gaugeSpan, min(gaugeSpan, (cents / 50) * gaugeSpan))
    }

    // MARK: Phase math

    /// Shortest signed distance between two wrapped 0…1 phases, in (−0.5, 0.5].
    /// Called by all phase-scroll renderers (Aurora, Radial, Metal).
    static func wrappedDelta(_ a: Double, _ b: Double) -> Double {
        var d = b - a
        d -= d.rounded()
        return d
    }

    // MARK: WCAG 2.3.1 photosensitivity guard (Lever C — rate ceiling + danger-band dim)
    //
    // Analysis: docs/solutions/accessibility/strobe-photosensitivity-2026-06-19.md.
    // The off-pitch strobe is a full-screen, high-contrast, rigidly-translating
    // pattern of `ribbonCount` bands; a fixed point flickers at
    // `ribbonCount × translationRate` (the per-region flicker). To satisfy WCAG
    // 2.3.1 the field must, at all times, either flicker ≤ 3/sec OR keep its
    // luminance swing below 10% of max. The two helpers below enforce that
    // *by construction*:
    //   • `clampedStrobeRate` — an AESTHETIC ceiling on visible drift speed.
    //     NOT the safety mechanism; chosen for feel (see `maxStrobeRateHz`).
    //   • `photosensitivityBrightness` — the SAFETY mechanism: a brightness
    //     multiplier that drops to `shimmerFloor` whenever the per-region flicker
    //     would exceed `flashSafeRegionHz`, sized so the resulting swing ≤ the
    //     flash threshold. Sub-threshold is a low-contrast *shimmer*, not black —
    //     direction + motion stay readable; full vividness + bloom return at lock
    //     (where the eased rate → 0, so the multiplier → 1).
    //
    // The luminance model (`peakLuminanceSwing`) comes from the C-4a analysis,
    // not an on-device photometer — the guard is verified against that model
    // (see PhotosensitivityClampTests), and the rate-ceiling value is engineering
    // judgement, not a measured constant.

    /// WCAG general-flash limit: a large region must not reverse more than this
    /// many times per second.
    static let flashSafeRegionHz: Double = 3.0

    /// Modeled peak relative-luminance swing of the brightest off-pitch band over
    /// the near-black field (C-4a §4: α≈0.6 of mint #28F0C0 ≈ 0.40).
    static let peakLuminanceSwing: Double = 0.40

    /// WCAG general-flash threshold: an opposing luminance change ≥ this fraction
    /// of max relative luminance counts as a flash.
    static let flashLuminanceFraction: Double = 0.10

    /// Brightness floor in the danger band — sized so `peakLuminanceSwing × floor
    /// ≤ flashLuminanceFraction` (0.10 / 0.40 = 0.25). Keeps a visible shimmer.
    static let shimmerFloor: Double = flashLuminanceFraction / peakLuminanceSwing

    /// Aesthetic ceiling on off-pitch translation/rotation speed (cycles/sec).
    /// Bounds how fast the field visibly drifts; safety is handled by the
    /// brightness guard, so this is a feel knob (engineering judgement).
    static let maxStrobeRateHz: Double = 4.0

    /// Clamp a signed translation/rotation rate (cycles/sec) to ±`maxStrobeRateHz`,
    /// preserving sign (direction).
    static func clampedStrobeRate(_ rate: Double) -> Double {
        max(-maxStrobeRateHz, min(maxStrobeRateHz, rate))
    }

    /// Brightness multiplier (∈ [`shimmerFloor`, 1]) for the off-pitch field that
    /// keeps it WCAG-2.3.1-compliant by construction, given the C-4a luminance
    /// model. `rateHz` is the *effective on-screen* translation rate (already
    /// rate-capped and lock-eased); `ribbonCount` is the band/mark count (the
    /// spatial flicker multiplier).
    ///
    /// - flicker `= ribbonCount × |rateHz|` ≤ `flashSafeRegionHz − 1` → `1.0`
    ///   (full vividness; safe because the region reverses ≤ 2/sec).
    /// - flicker ≥ `flashSafeRegionHz` → `shimmerFloor`
    ///   (swing ≤ 10% of max → not a "flash").
    /// - in between → linear ramp, so vividness returns smoothly as the note
    ///   converges (and is `1.0` at lock, where `rateHz → 0`).
    static func photosensitivityBrightness(rateHz: Double, ribbonCount: Int) -> Double {
        let flicker = Double(ribbonCount) * abs(rateHz)
        let rampStart = flashSafeRegionHz - 1   // begin dimming 1 Hz before the limit
        if flicker <= rampStart { return 1 }
        if flicker >= flashSafeRegionHz { return shimmerFloor }
        let t = (flicker - rampStart) / (flashSafeRegionHz - rampStart)   // 0→1
        return 1 + (shimmerFloor - 1) * t
    }
}
