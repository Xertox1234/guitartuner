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
}
