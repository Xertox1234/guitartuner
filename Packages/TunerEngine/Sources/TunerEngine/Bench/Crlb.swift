import Foundation

/// The Cramér–Rao lower bound for frequency estimation — the *statistical floor*
/// no unbiased estimator can beat (Rife & Boorstyn 1974; harmonic form
/// Christensen/Nielsen). P0 needs this so the benchmark can quote a measured σ as
/// a multiple of the physical limit ("within X× of the floor"), and so the §16
/// diagnosis (Plan 06 §2.3, §3) becomes a CI regression rather than a claim.
///
/// Conventions (matched to the committed `diagnosis.swift` probe C):
/// - `snr` is the **linear power** SNR *per partial* (so the single-tone and
///   harmonic forms share one reference).
/// - `harmonicWeight` is `Σ A_k²·k²` over the partials (index 0 ⇒ partial 1).
///   Equal-amplitude partials give `Σ k²`; the realistic ∝1/k synthesis gives a
///   far smaller weight — the honest reason the harmonic floor is closer to the
///   single-tone floor than an equal-amplitude analysis suggests.
public enum Crlb {

    /// dB SNR → linear power ratio.
    public static func snrLinear(dB: Double) -> Double { pow(10, dB / 10) }

    /// `var(f̂)` for a single real sinusoid in white noise, in Hz²:
    ///   `var(f̂) ≥ 6·fs² / ((2π)²·SNR·N(N²−1))`.
    public static func frequencyVarianceSingle(sampleRate fs: Double, n: Int, snr: Double) -> Double {
        guard n > 1, snr > 0 else { return .infinity }
        let N = Double(n)
        return 6 * fs * fs / (pow(2 * .pi, 2) * snr * N * (N * N - 1))
    }

    /// `var(f̂0)` for a harmonic tone, in Hz²:
    ///   `var(f̂0) ≥ 6·fs² / ((2π)²·SNR·N(N²−1)·Σ A_k² k²)`.
    /// The `Σ A_k² k²` term — dominated by the high partials — is the whole game.
    public static func frequencyVarianceHarmonic(
        sampleRate fs: Double, n: Int, snr: Double, harmonicWeight: Double
    ) -> Double {
        guard harmonicWeight > 0 else { return .infinity }
        return frequencyVarianceSingle(sampleRate: fs, n: n, snr: snr) / harmonicWeight
    }

    /// `Σ A_k²·k²` for partial amplitudes `amplitudes` (index 0 ⇒ partial 1).
    /// Pair this with a **per-partial** SNR (the probe-C convention).
    public static func harmonicWeight(amplitudes: [Double]) -> Double {
        var s = 0.0
        for (i, a) in amplitudes.enumerated() {
            let k = Double(i + 1)
            s += a * a * k * k
        }
        return s
    }

    /// `Σ p_k·k²` with `p_k = A_k²/Σ A_j²` — the *normalised* harmonic weight to
    /// pair with a **total** SNR (the `Synth.addNoise` convention, where SNR is
    /// total signal power ÷ noise power). Equals `harmonicWeight / Σ A_k²`.
    /// For ∝1/k partials this is ~6.5, not the ~38× an equal-amplitude reading
    /// implies — the honest realistic harmonic gain.
    public static func normalizedHarmonicWeight(amplitudes: [Double]) -> Double {
        let denom = amplitudes.reduce(0) { $0 + $1 * $1 }
        guard denom > 0 else { return 0 }
        return harmonicWeight(amplitudes: amplitudes) / denom
    }

    /// Convert a frequency std-dev (Hz) at `f0` into cents.
    public static func centsStdDev(frequencyStdDev sigmaF: Double, f0: Double) -> Double {
        guard f0 > 0, sigmaF.isFinite else { return .infinity }
        return 1200 / log(2.0) * sigmaF / f0
    }

    /// One-call bound in **cents** for a single sinusoid.
    public static func boundCentsSingle(sampleRate fs: Double, n: Int, snrDB: Double, f0: Double) -> Double {
        let v = frequencyVarianceSingle(sampleRate: fs, n: n, snr: snrLinear(dB: snrDB))
        return centsStdDev(frequencyStdDev: v.squareRoot(), f0: f0)
    }

    /// One-call bound in **cents** for a harmonic tone of the given partial weight.
    public static func boundCentsHarmonic(
        sampleRate fs: Double, n: Int, snrDB: Double, f0: Double, harmonicWeight: Double
    ) -> Double {
        let v = frequencyVarianceHarmonic(
            sampleRate: fs, n: n, snr: snrLinear(dB: snrDB), harmonicWeight: harmonicWeight)
        return centsStdDev(frequencyStdDev: v.squareRoot(), f0: f0)
    }

    // MARK: - Sample-clock (ppm) honesty — Plan 06 §3, §7

    /// Absolute pitch error (cents) from a sample-clock offset of `ppm`.
    /// `f = cycles × sample_rate`, so a clock that is `ppm` fast reads `ppm` sharp.
    public static func centsFromPPM(_ ppm: Double) -> Double { 1200 * log2(1 + ppm / 1e6) }

    /// ppm equivalent of one cent (≈ 577.8) — the unit that makes the clock floor
    /// legible: a 44 ppm crystal is already 0.076 ¢ of *absolute* error.
    public static var ppmPerCent: Double { 1e6 * (pow(2, 1.0 / 1200) - 1) }
}
