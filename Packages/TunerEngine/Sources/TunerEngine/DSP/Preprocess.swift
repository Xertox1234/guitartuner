import Foundation

/// A transposed-direct-form-II biquad — one stateful second-order IIR section.
/// Used for the rumble high-pass; cheap and numerically stable in `Double`.
struct Biquad {
    // Normalised coefficients (a0 == 1).
    let b0: Double, b1: Double, b2: Double, a1: Double, a2: Double
    private var z1: Double = 0
    private var z2: Double = 0

    init(b0: Double, b1: Double, b2: Double, a1: Double, a2: Double) {
        self.b0 = b0; self.b1 = b1; self.b2 = b2; self.a1 = a1; self.a2 = a2
    }

    /// 2nd-order Butterworth high-pass (Q = 1/√2) at `cutoff` Hz.
    static func highpass(cutoff: Double, sampleRate: Double) -> Biquad {
        let q = 1.0 / 2.0.squareRoot()
        let w0 = 2 * Double.pi * cutoff / sampleRate
        let cosw = cos(w0)
        let alpha = sin(w0) / (2 * q)
        let a0 = 1 + alpha
        return Biquad(
            b0: (1 + cosw) / 2 / a0,
            b1: -(1 + cosw) / a0,
            b2: (1 + cosw) / 2 / a0,
            a1: (-2 * cosw) / a0,
            a2: (1 - alpha) / a0
        )
    }

    mutating func process(_ x: Double) -> Double {
        let y = b0 * x + z1
        z1 = b1 * x - a1 * y + z2
        z2 = b2 * x - a2 * y
        return y
    }

    mutating func reset() { z1 = 0; z2 = 0 }
}

/// Front-of-pipeline conditioning: a one-pole **DC blocker** (kills any DC bias
/// from the converter) followed by a 2nd-order **high-pass** at ~28 Hz to remove
/// sub-audio rumble below the lowest note we track (DESIGN §3). Stateful: run it
/// on the continuous sample stream *before* windowing so there are no per-window
/// edge transients.
struct Preprocessor {
    private var hp: Biquad
    private var dcX1: Double = 0
    private var dcY1: Double = 0
    private let dcR: Double

    /// `cutoff` ~25–30 Hz keeps low B (~31 Hz) intact while removing rumble.
    init(sampleRate: Double, cutoff: Double = 28) {
        self.hp = .highpass(cutoff: cutoff, sampleRate: sampleRate)
        // DC blocker pole near 1; ~5 Hz corner is well below everything musical.
        self.dcR = 1 - (2 * Double.pi * 5 / sampleRate)
    }

    /// Filter one sample (DC block → high-pass).
    mutating func process(_ x: Float) -> Float {
        let xd = Double(x)
        let dc = xd - dcX1 + dcR * dcY1
        dcX1 = xd
        dcY1 = dc
        return Float(hp.process(dc))
    }

    mutating func reset() {
        hp.reset(); dcX1 = 0; dcY1 = 0
    }
}

/// Hann window — applied to each analysis frame before correlation / the
/// single-bin DFT. Pure (no shared cache, so it's concurrency-safe); the pipeline
/// caches the window for its current length per-instance.
enum Windowing {
    static func hann(_ n: Int) -> [Float] {
        var w = [Float](repeating: 0, count: n)
        if n > 1 {
            let scale = 2 * Double.pi / Double(n - 1)
            for i in 0..<n {
                w[i] = Float(0.5 - 0.5 * cos(scale * Double(i)))
            }
        }
        return w
    }
}
