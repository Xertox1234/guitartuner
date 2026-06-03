import Foundation

/// Pure waveform math for the optional `Oscilloscope`, ported from
/// `docs/design_reference/oscilloscope.jsx`. The scope is **stylised, not a raw
/// capture** — the trace is synthesised from the note's frequency and cents error
/// (a sum of harmonics with a little texture + a detune wobble, windowed at the
/// edges). Kept SwiftUI-free so it's unit-testable, like `StrobeMath`.
enum ScopeMath {
    /// Scroll rate (cycles/sec scale) of the animated trace — higher notes scroll
    /// a little faster. `1.2 + (freq/330)·1.4`.
    static func visualRate(freq: Double) -> Double {
        1.2 + (freq / 330) * 1.4
    }

    /// How many wave cycles span the scope width — denser for higher notes.
    /// `3.2 + (freq/200)·1.4`.
    static func cycles(freq: Double) -> Double {
        3.2 + (freq / 200) * 1.4
    }

    /// Normalised, edge-windowed waveform value at position `u` ∈ [0, 1] for the
    /// current scroll `phase` (radians), wave `cycles`, and `cents` detune. The
    /// result is bounded to roughly ±1.83 (the sum of the harmonic weights).
    static func sample(u: Double, phase: Double, cycles: Double, cents: Double) -> Double {
        let ang = u * 2 * .pi * cycles + phase
        var y = sin(ang)
        y += sin(ang * 2 + 0.4) * 0.42
        y += sin(ang * 3 + 0.9) * 0.20
        y += sin(ang * 4 + 1.2) * 0.10
        y += sin(u * 543.21 + phase * 17.3) * 0.06     // fine texture
        y += sin(ang + cents * 0.12 + phase * 0.3) * 0.05   // cents wobble
        let env = 0.7 + 0.3 * sin(u * .pi)              // fade in/out at the edges
        return y * env
    }
}
