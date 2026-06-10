import Foundation

/// Weighted least-squares fit of the stiff-string inharmonic model
///     fₙ = n · f0 · √(1 + B · n²)
///
/// Linearised form: (fₙ/n)² = f0² + f0²·B·n²
///   → regress  yᵢ = a + b·xᵢ   (xᵢ = nᵢ², yᵢ = (freqᵢ/nᵢ)²)
///   → f0 = √a,  B = b / a
///
/// Called by `HarmonicEstimator`; also directly testable (Plan 06 §2.5, §5.3).
enum Inharmonicity {

    /// One partial measurement with its analysis weight.
    struct Measurement {
        /// Harmonic number (1 = fundamental).
        let n: Int
        /// Refined frequency of this partial (Hz).
        let frequency: Double
        /// Fisher weight ∝ n²·SNR (positive). Measurements with weight ≤ 0 are ignored.
        let weight: Double
    }

    /// Result of the joint (f0, B) regression.
    struct Fit {
        /// Estimated fundamental (Hz).
        let f0: Double
        /// Inharmonicity coefficient (≥ 0). Stiffness constant in `fₙ = n·f0·√(1+B·n²)`.
        let B: Double
        /// RMS of per-partial Hz residuals |fₙ_measured − fₙ_predicted|.
        let residualRMS: Double
        /// Number of measurements used in this fit.
        let partialCount: Int
    }

    /// Weighted ordinary least-squares fit. Returns `nil` when fewer than 2
    /// measurements are provided, the normal-equation determinant is degenerate,
    /// or the fitted f0² is non-positive.
    static func fit(_ measurements: [Measurement]) -> Fit? {
        let valid = measurements.filter { $0.weight > 0 }
        guard valid.count >= 2 else { return nil }

        var S0 = 0.0, S1 = 0.0, S2 = 0.0
        var T0 = 0.0, T1 = 0.0
        for m in valid {
            let x  = Double(m.n * m.n)
            let fn = m.frequency / Double(m.n)
            let y  = fn * fn
            let w  = m.weight
            S0 += w;     S1 += w * x;     S2 += w * x * x
            T0 += w * y; T1 += w * x * y
        }
        let det = S0 * S2 - S1 * S1
        guard det.magnitude > 1e-30 else { return nil }

        let a = (T0 * S2 - T1 * S1) / det   // f0²
        let b = (S0 * T1 - S1 * T0) / det   // f0²·B
        guard a > 0 else { return nil }

        let f0 = a.squareRoot()
        let B  = max(0, b / a)               // inharmonicity is non-negative by physics

        var sumSq = 0.0
        for m in valid {
            let fPred = partialFrequency(n: m.n, f0: f0, B: B)
            let r = m.frequency - fPred
            sumSq += r * r
        }
        let residualRMS = (sumSq / Double(valid.count)).squareRoot()

        return Fit(f0: f0, B: B, residualRMS: residualRMS, partialCount: valid.count)
    }

    /// Predicted frequency of partial n under the stiff-string model.
    @inline(__always)
    static func partialFrequency(n: Int, f0: Double, B: Double) -> Double {
        Double(n) * f0 * (1.0 + B * Double(n * n)).squareRoot()
    }
}
