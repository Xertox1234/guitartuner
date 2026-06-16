import Foundation
#if canImport(Accelerate)
import Accelerate
#endif

/// Shared correlation/energy terms for the pitch detectors. Both McLeod's NSDF
/// and YIN's difference function are exact functions of the **type-II
/// autocorrelation** `r(τ) = Σ_{j} x[j]·x[j+τ]` and the windowed energies, so we
/// compute those once and let MPM and YIN share them (cheap hybrid).
///
/// Relationships used downstream:
///   m(τ)  = Σ_{j=0}^{N-1-τ}(x[j]² + x[j+τ]²)  = P[N-τ] + P[N] - P[τ]
///   NSDF  = 2·r(τ) / m(τ)                       ∈ [-1, 1]   (McLeod)
///   YIN d = m(τ) - 2·r(τ)                        ≥ 0         (difference fn)
/// where P is the prefix sum of squares.
struct Correlation {
    /// `r[τ]` for τ in 0…maxLag (true units: Σ x[j]·x[j+τ]).
    let r: [Double]
    /// Prefix sum of squares: `P[k] = Σ_{i<k} x[i]²`, length N+1.
    let prefixEnergy: [Double]
    let count: Int          // N (window length)
    let maxLag: Int

    /// m(τ) — the NSDF/YIN normaliser.
    @inline(__always) func m(_ tau: Int) -> Double {
        prefixEnergy[count - tau] + prefixEnergy[count] - prefixEnergy[tau]
    }

    /// NSDF n'(τ) ∈ [-1, 1]; 0 when m(τ) is ~0 (silence).
    @inline(__always) func nsdf(_ tau: Int) -> Double {
        let mt = m(tau)
        guard mt > 1e-12 else { return 0 }
        return 2 * r[tau] / mt
    }

    /// YIN difference d(τ) ≥ 0.
    @inline(__always) func yinDifference(_ tau: Int) -> Double {
        max(0, m(tau) - 2 * r[tau])
    }

    /// Compute `r` (0…maxLag) and the prefix energy for a window.
    static func compute(_ x: [Float], maxLag: Int) -> Correlation {
        let n = x.count
        let lag = min(maxLag, n - 1)

        // Prefix sum of squares in Double for a numerically clean m(τ).
        var prefix = [Double](repeating: 0, count: n + 1)
        #if canImport(Accelerate)
        var sq = [Float](repeating: 0, count: n)
        vDSP_vsq(x, 1, &sq, 1, vDSP_Length(n))
        for i in 0..<n { prefix[i + 1] = prefix[i] + Double(sq[i]) }
        #else
        for i in 0..<n {
            let v = Double(x[i])
            prefix[i + 1] = prefix[i] + v * v
        }
        #endif

        var r = [Double](repeating: 0, count: lag + 1)
        #if canImport(Accelerate)
        // Each lag is a dot product over the overlapping span. vDSP_dotpr is a
        // tight SIMD loop; calling it per lag is simple and obviously correct.
        // (FFT-based autocorrelation is the on-device optimisation — noted.)
        x.withUnsafeBufferPointer { buf in
            let base = buf.baseAddress!
            for tau in 0...lag {
                var dot: Float = 0
                vDSP_dotpr(base, 1, base + tau, 1, &dot, vDSP_Length(n - tau))
                r[tau] = Double(dot)
            }
        }
        #else
        for tau in 0...lag {
            var dot = 0.0
            for j in 0..<(n - tau) {
                dot += Double(x[j]) * Double(x[j + tau])
            }
            r[tau] = dot
        }
        #endif

        return Correlation(r: r, prefixEnergy: prefix, count: n, maxLag: lag)
    }
}

/// Fit a parabola through three samples `(–1, y0), (0, y1), (1, y2)` and return
/// the offset of the vertex in [-1, 1] plus the interpolated peak value. The
/// sub-sample period precision that turns a coarse lag into sub-cent frequency
/// (DESIGN §3 "sub-cent refinement").
@inline(__always)
func parabolicVertex(_ y0: Double, _ y1: Double, _ y2: Double) -> (offset: Double, value: Double) {
    let denom = y0 - 2 * y1 + y2
    guard abs(denom) > 1e-15 else { return (0, y1) }
    let offset = 0.5 * (y0 - y2) / denom
    let value = y1 - 0.25 * (y0 - y2) * offset
    return (max(-1, min(1, offset)), value)
}
