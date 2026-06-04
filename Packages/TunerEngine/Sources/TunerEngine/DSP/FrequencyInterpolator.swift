import Foundation

/// Sub-bin spectral peak interpolation — turn three DFT samples around a peak
/// into the fractional-bin offset of the true frequency. The current pipeline's
/// raw **parabolic** interpolation carries ≈0.46 ¢ of irreducible bias (Plan 06
/// §2.2, reproduced in `Diagnosis.probeB`); this replaces it with **bias-
/// corrected** estimators that reach the Cramér–Rao floor.
///
/// All return `δ ∈ [−0.5, 0.5]`: the offset (in bins) of the peak from the
/// centre sample. Convert to Hz with `(k + δ)·sampleRate/N`.
enum FrequencyInterpolator {

    /// Quadratic (parabolic) interpolation on **linear** magnitudes — the method
    /// the engine uses today. ~0.46 ¢ worst-case bias (5.3 % of a bin). Kept for
    /// comparison and as the NSDF clarity-peak refiner (fine for confidence).
    static func parabolic(_ a: Double, _ b: Double, _ c: Double) -> Double {
        let denom = a - 2 * b + c
        guard abs(denom) > 1e-300 else { return 0 }
        return clamp(0.5 * (a - c) / denom)
    }

    /// Parabolic on **log** magnitudes (Gasior/Gaussian-window estimator). A
    /// Gaussian main lobe is an exact parabola in log-magnitude, and a Hann
    /// window is close — so this drops the bias to ~0.14 ¢ on the pipeline's
    /// Hann frames at near-zero cost.
    static func logParabolic(_ a: Double, _ b: Double, _ c: Double) -> Double {
        let la = log(max(a, 1e-300)), lb = log(max(b, 1e-300)), lc = log(max(c, 1e-300))
        return parabolic(la, lb, lc)
    }

    /// **Candan-2013** — fine frequency from three *complex* DFT samples of a
    /// **rectangular**-window transform. `q = (X₋₁−X₊₁)/(2X₀−X₋₁−X₊₁)`, then the
    /// exact bias correction `δ = (N/π)·atan(tan(π/N)·Re q)`. Near-CRLB
    /// (≈1.01–1.02× the bound), two orders of magnitude past parabolic.
    static func candan(
        _ km1: (re: Double, im: Double),
        _ k0: (re: Double, im: Double),
        _ kp1: (re: Double, im: Double),
        n: Int
    ) -> Double {
        let numRe = km1.re - kp1.re, numIm = km1.im - kp1.im
        let denRe = 2 * k0.re - km1.re - kp1.re, denIm = 2 * k0.im - km1.im - kp1.im
        let denMag2 = denRe * denRe + denIm * denIm
        guard denMag2 > 1e-300 else { return 0 }
        // Re(num / den) = Re(num · conj(den)) / |den|².
        let reQ = (numRe * denRe + numIm * denIm) / denMag2
        let t = tan(Double.pi / Double(n))
        return clamp(Double(n) / Double.pi * atan(t * reQ))
    }

    @inline(__always) private static func clamp(_ x: Double) -> Double {
        x.isFinite ? max(-0.5, min(0.5, x)) : 0
    }
}
