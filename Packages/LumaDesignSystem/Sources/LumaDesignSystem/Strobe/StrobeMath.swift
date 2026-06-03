import Foundation

/// Pure strobe math ported from `strobe-aurora.jsx` / `strobe-core.jsx`. Kept
/// free of SwiftUI so it's unit-testable.
enum StrobeMath {
    /// Number of Aurora ribbons.
    static let ribbonCount = 13

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

    // MARK: Reduced-motion gauge

    /// Degrees swept either side of centre.
    static let gaugeSpan: Double = 122

    /// cents (−50…50) → dial angle in degrees (0 = up), clamped to ±span.
    static func gaugeAngle(cents: Double) -> Double {
        max(-gaugeSpan, min(gaugeSpan, (cents / 50) * gaugeSpan))
    }
}
