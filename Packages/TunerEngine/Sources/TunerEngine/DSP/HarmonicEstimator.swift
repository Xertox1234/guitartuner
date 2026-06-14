import Foundation
#if canImport(Accelerate)
import Accelerate
#endif

/// Inharmonic-comb fundamental estimator — Plan 06 P2 centrepiece.
///
/// Replaces the phase-vocoder sub-cent refine for bass (f0 < 120 Hz) with a
/// multi-partial approach: locate every audible partial, jointly fit `(f0, B)`
/// via the linearised stiff-string regression, and return a Fisher-weighted f0
/// whose variance scales as `1/Σnₖ²·SNRₖ` — orders of magnitude below the
/// single-fundamental ACF estimate (Plan 06 §2.3, §5.3, CRLB table).
///
/// Tolerates weak or missing fundamentals: the 2nd–12th partials carry the
/// frequency information on low strings. The magnitude gate simply excludes the
/// weak k = 1 bin from the weights rather than aborting.
///
/// MPM remains the sole octave authority; the precision stack never moves f0 by
/// more than `maxF0ShiftCents` from the MPM estimate (Plan 06 §4, §6).
enum HarmonicEstimator {

    struct Result {
        /// Refined fundamental frequency (Hz).
        let frequency: Double
        /// Estimated inharmonicity coefficient B (stiff-string model, ≥ 0).
        let inharmonicityB: Double
        /// Number of partials that contributed to the fit.
        let partialCount: Int
    }

    // MARK: - Tuning constants

    /// Precision-stack octave-safety bound (cents). The harmonic fit can never
    /// move f0 outside ±50 ¢ of MPM's estimate (MPM stays the octave authority).
    static let maxF0ShiftCents: Double = 50.0

    /// Partials weaker than this fraction of the loudest detected partial are
    /// excluded from the regression (noise rejection; missing-fundamental safe).
    static let minRelativeMagnitude: Double = 0.04

    /// Minimum number of valid partials required for the (f0, B) joint fit.
    static let minPartials: Int = 3

    /// Partials below this original-bin index are excluded. At very low bins the
    /// DC image plus proximity of n−1 contaminates the Candan triplet: for B0
    /// (30.87 Hz) n=1 is at bin 2.6 and n=2 at bin 5.3 — both inside the danger
    /// zone. Raising from 4 to 6 drops n=2 from the regression for B0/A0 while
    /// keeping n=1 for E2 (bin 7.0) and all mid-range strings.
    static let minBin: Double = 6.0

    // MARK: - Refine

    /// Refine `f0` using the full harmonic comb in `frame`.
    ///
    /// - Parameters:
    ///   - frame:       Pre-processed (DC-blocked, high-passed) analysis window.
    ///                  Not pre-windowed — `refine` applies Hann internally once
    ///                  and passes the result to `refineFundamental` as needed.
    ///   - f0:          MPM's octave-safe fundamental (Hz). Search anchor; the
    ///                  result is clamped within `maxF0ShiftCents` of this value.
    ///   - sampleRate:  Capture sample rate (Hz).
    ///   - maxPartials: Hard upper bound on partial count; iteration stops at Nyquist.
    static func refine(
        _ frame: [Float],
        near f0: Double,
        sampleRate: Double,
        maxPartials: Int = 12
    ) -> Result? {
        let nyquist = sampleRate / 2

        // ── Step 1: locate & refine each partial (B = 0 seed) ─────────────────
        // Integer-bin Candan via refineFundamental (±2-bin search, near-CRLB for
        // well-separated partials). The magnitude-gate then weights each partial
        // by n²·SNR so the OLS regression is Fisher-optimal.
        //
        // Partials below minBin are skipped: at very low bins the DC image plus
        // proximity of the n−1 neighbour contaminates the Candan triplet. For B0
        // (30.87 Hz) n=1 is at bin 2.6 and n=2 at bin 5.3 — both below 6. Keeping
        // minBin=6 drops those two from the regression while retaining n=1 for E2
        // (bin 7.0) and all mid/high strings. The higher-n partials carry the
        // frequency information (Fisher weight ∝ n²·SNR) so the loss is minor.
        let binSpacing = sampleRate / Double(frame.count)

        // Pre-compute one Hann-windowed copy of the frame, shared across all
        // partial refinements below. At very low bass (partial spacing ~2.6 bins)
        // Candan (rectangular window) and log-parabolic (Hann window) accumulate
        // opposite-signed inter-partial leakage biases (~+2.3¢ vs ~-2.4¢ for B0).
        // Averaging per-partial cancels most of the systematic offset.
        // One allocation here vs one per partial in logParabolicHann.
        var hannFrame = frame
        let win = Windowing.hann(frame.count)
        #if canImport(Accelerate)
        vDSP_vmul(hannFrame, 1, win, 1, &hannFrame, 1, vDSP_Length(frame.count))
        #else
        for i in 0..<hannFrame.count { hannFrame[i] *= win[i] }
        #endif

        var collected: [(n: Int, freq: Double, mag: Double)] = []
        collected.reserveCapacity(maxPartials)

        for n in 1...maxPartials {
            let fPred = Double(n) * f0
            guard fPred < nyquist * 0.95 else { break }
            guard fPred / binSpacing >= minBin else { continue }

            let fCandan = SpectralAnalyzer.refineFundamental(
                frame, near: fPred, sampleRate: sampleRate, interp: .candan, maxCents: 50
            )
            let fHann = SpectralAnalyzer.refineFundamental(
                hannFrame, near: fPred, sampleRate: sampleRate, interp: .logParabolicPreHanned, maxCents: 50
            )
            let fRef = (fCandan + fHann) * 0.5
            let mag = SpectralAnalyzer.magnitude(frame, frequency: fRef, sampleRate: sampleRate)
            collected.append((n: n, freq: fRef, mag: mag))
        }
        guard !collected.isEmpty else { return nil }

        // ── Step 2: magnitude gate + Fisher-weighted measurements ──────────────
        let peakMag = collected.max { $0.mag < $1.mag }!.mag
        guard peakMag > 0 else { return nil }
        let magGate = peakMag * minRelativeMagnitude

        // Fisher weight w ∝ n²·SNR. Approximate SNR ∝ mag² (equal noise floor
        // across bins is a reasonable assumption for short bass frames).
        var measurements: [Inharmonicity.Measurement] = []
        for item in collected where item.mag >= magGate {
            let w = Double(item.n * item.n) * item.mag * item.mag
            measurements.append(.init(n: item.n, frequency: item.freq, weight: w))
        }
        guard measurements.count >= minPartials else { return nil }

        // ── Step 3: first (f0, B) fit ──────────────────────────────────────────
        guard var fit = Inharmonicity.fit(measurements) else { return nil }

        // ── Step 4: outlier rejection ──────────────────────────────────────────
        // A partial whose |residual| > 3·σ_rms is likely a noise hit or a
        // spurious tone. Dropping it and re-fitting removes anti-octave and
        // anti-spurious contamination. The 1 Hz floor prevents over-aggressive
        // rejection in very-low-noise frames (Plan 06 §5.3, §6).
        if measurements.count >= 4 {
            let gate = max(3.0 * fit.residualRMS, 1.0)
            let trimmed = measurements.filter { m in
                let fPred = Inharmonicity.partialFrequency(n: m.n, f0: fit.f0, B: fit.B)
                return abs(m.frequency - fPred) <= gate
            }
            if trimmed.count >= minPartials, let fit2 = Inharmonicity.fit(trimmed) {
                fit = fit2
                measurements = trimmed
            }
        }

        // ── Step 5: octave-safety clamp ────────────────────────────────────────
        let centsShift = 1200.0 * log2(fit.f0 / f0)
        guard abs(centsShift) <= maxF0ShiftCents else { return nil }

        return Result(frequency: fit.f0, inharmonicityB: fit.B, partialCount: fit.partialCount)
    }
}
