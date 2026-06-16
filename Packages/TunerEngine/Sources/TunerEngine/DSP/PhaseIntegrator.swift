import Foundation
#if canImport(Accelerate)
import Accelerate
#endif

/// Tretter long-window phase-slope fundamental estimator (Plan 06 P3 centrepiece).
///
/// On sustained notes, integrates the *residual* unwrapped phase of each audible
/// partial across the held interval and least-squares the slope (angular frequency
/// deviation from the reference). Fisher-weighted fusion across partials approaches
/// the CRLB: sub-0.05 ¢ σ after ~0.5 s, ~0.003 ¢ at 1 s with 10 partials
/// (Plan 06 §5.4, reproduced numbers).
///
/// ### Phase accumulation
/// At hop i, the single-bin DFT at partial reference frequency `fRef_n` gives
/// angle θ_i = atan2(im, re). Between consecutive hops separated by dt seconds,
/// a tone exactly at fRef_n advances by 2π·fRef_n·dt radians, so
///
///   residual Δφ = princarg(θ_i − θ_{i-1} − 2π·fRef_n·dt) ≈ 0
///
/// If the actual frequency is fRef_n + ε, then Δφ ≈ 2π·ε·dt per hop.
/// Accumulating cumPhase = Σ Δφ and LS-fitting its slope gives ε in rad/s.
///
/// Relationship to StrobePhase: uses the same single-bin DFT kernel
/// (`StrobePhase.bin`) but accumulates across many hops rather than differencing
/// one consecutive pair. The strobe visual contract (phase, 0…1) is unaffected.
///
/// Reset triggers: note change (>50 ¢ from reference f0), explicit `reset()` call
/// from the pipeline on silence / unvoiced streak.
struct PhaseIntegrator {

    // MARK: - Tuning constants

    /// Minimum hops before the first estimate is emitted (~0.43 s at the bass rate).
    static let minHops: Int = 20

    /// Maximum accumulated hops; older entries stop being appended once the cap is
    /// hit. Accuracy keeps improving with window length, but we bound memory and
    /// the O(N) LS computation.
    static let maxHops: Int = 140   // ~3 s at bass hop rate

    /// Partials weaker than this fraction of the loudest partial are excluded.
    /// Spectral leakage from adjacent partials (or from a pure tone's sidelobes)
    /// drives the DFT at missing harmonic bins with a wrong phase trajectory,
    /// biasing the LS slope. The gate suppresses those bins.
    /// Matches `HarmonicEstimator.minRelativeMagnitude`.
    static let minRelativeMagnitude: Double = 0.04

    /// Frequency shift (relative to the reference f0 fixed at integration start)
    /// that triggers a full reset. Matches `HarmonicEstimator.maxF0ShiftCents`.
    static let resetCents: Double = 50.0

    // MARK: - Per-partial state

    private struct PartialState {
        var prevAngle: Double   // atan2 of previous hop's DFT bin (radians)
        var prevTime: Double    // frame centre time of previous hop (seconds)
        var cumPhase: Double    // accumulated residual phase (radians, starts at 0)
        var times: [Double]     // seconds from integration start (one per hop)
        var phases: [Double]    // cumPhase values (one per hop)
        var mag: Double         // magnitude of the latest DFT bin (for weighting)
    }

    // MARK: - State

    private static let maxPartials_default: Int = 10

    private var partials: [PartialState?]   // index = n-1; n = 1…maxPartials
    private var refF0: Double?              // f0 at integration start (fixed reference)
    private var refB: Double = 0            // B at integration start (fixed reference)
    private var startTime: Double?
    private var hopCount: Int = 0

    // MARK: - Output

    struct Result {
        /// Refined fundamental frequency (Hz), Fisher-fused across partials.
        let f0: Double
        /// Estimated ±σ of `f0` in cents (lower bound from best-partial LS residuals).
        let precisionCents: Double
    }

    // MARK: - Init

    init() {
        partials = Array(repeating: nil, count: Self.maxPartials_default)
    }

    // MARK: - Feed

    /// Advance the integrator by one hop.
    ///
    /// - Parameters:
    ///   - frame:       Raw (not pre-windowed) preprocessed analysis frame.
    ///   - f0:          Current best-estimate fundamental (Hz) from P1/P2 + smoother.
    ///                  Sets the reference on the first call after a reset; also used
    ///                  as the octave-safety anchor for the emitted result.
    ///   - inharmonicityB: Current B estimate (0 if unavailable).
    ///   - sampleRate:  Capture sample rate (Hz).
    ///   - frameTime:   Seconds of this frame's centre (monotonic, audio clock).
    ///   - maxPartials: Upper bound on partial count (default 10; override in tests).
    /// - Returns: A fused f0 estimate once `minHops` frames have accumulated, else `nil`.
    mutating func feed(
        frame: [Float],
        f0: Double,
        inharmonicityB: Double = 0,
        sampleRate: Double,
        frameTime: Double,
        maxPartials: Int = maxPartials_default
    ) -> Result? {
        // ── Reset guard: note change ──────────────────────────────────────────
        if let ref = refF0 {
            let shift = abs(1200.0 * log2(f0 / ref))
            if shift > Self.resetCents { reset() }
        }

        // ── Initialise reference on first frame ───────────────────────────────
        if refF0 == nil {
            refF0 = f0
            refB = inharmonicityB
            startTime = frameTime
        }
        guard let refF0, let startTime else { return nil }
        let t = frameTime - startTime
        hopCount += 1

        // ── Accumulate per-partial residual phase ─────────────────────────────
        let nyquist = sampleRate / 2
        for n in 1...maxPartials {
            let fRef_n = partialFreq(n: n, f0: refF0, B: refB)
            guard fRef_n < nyquist * 0.95 else { break }

            let c = StrobePhase.bin(frame, frequency: fRef_n, sampleRate: sampleRate)
            let angle = atan2(c.im, c.re)
            let mag = (c.re * c.re + c.im * c.im).squareRoot()

            let idx = n - 1

            if var state = partials[idx] {
                // Subtract the expected phase advance at fRef_n over this hop.
                // Without this subtraction, cumPhase would grow at 2π·fRef_n·dt
                // per hop even when f_actual == fRef_n, producing a spurious slope.
                let dt = t - state.prevTime
                let expectedAdvance = 2 * Double.pi * fRef_n * dt
                let delta = StrobePhase.princarg(angle - state.prevAngle - expectedAdvance)

                state.cumPhase += delta
                state.prevAngle = angle
                state.prevTime = t   // t is already relative to startTime
                state.mag = mag

                if state.times.count < Self.maxHops {
                    state.times.append(t)
                    state.phases.append(state.cumPhase)
                }
                partials[idx] = state
            } else {
                // First hop for this partial: cumPhase = 0 at this time origin.
                partials[idx] = PartialState(
                    prevAngle: angle,
                    prevTime: t,
                    cumPhase: 0,
                    times: [t],
                    phases: [0],
                    mag: mag
                )
            }
        }

        guard hopCount >= Self.minHops else { return nil }
        return estimate(anchor: f0, refF0: refF0, maxPartials: maxPartials)
    }

    // MARK: - Reset

    mutating func reset() {
        for i in partials.indices { partials[i] = nil }
        refF0 = nil
        startTime = nil
        hopCount = 0
    }

    // MARK: - Private helpers

    /// Stiff-string partial frequency: n·f0·√(1 + B·n²).
    private func partialFreq(n: Int, f0: Double, B: Double) -> Double {
        Double(n) * f0 * (B > 0 ? (1.0 + B * Double(n * n)).squareRoot() : 1.0)
    }

    /// Compute the fused f0 estimate from accumulated residual phase histories.
    private func estimate(anchor: Double, refF0: Double, maxPartials: Int) -> Result? {
        let B = refB

        // Magnitude gate: partials dominated by spectral leakage (rather than
        // actual signal energy) have systematically wrong phase trajectories and
        // must be excluded before the LS fit. For a pure tone, only the
        // fundamental bin passes; for a string with harmonics, all real partials
        // pass while empty spectral bins stay below the floor.
        var peakMag = 0.0
        for n in 1...maxPartials {
            if let state = partials[n - 1] { peakMag = max(peakMag, state.mag) }
        }
        guard peakMag > 0 else { return nil }
        let magGate = peakMag * Self.minRelativeMagnitude

        var sumW = 0.0, sumWf0 = 0.0
        var bestSigmaF0Hz = Double.infinity

        for n in 1...maxPartials {
            guard let state = partials[n - 1],
                  state.times.count >= 3,
                  state.mag >= magGate else { continue }

            // LS slope of cumPhase vs time → Δω_n (rad/s deviation from fRef_n).
            let (slope, sigma_slope) = lsSlope(times: state.times, phases: state.phases)

            // Recover actual partial frequency and map back to f0.
            let fRef_n = partialFreq(n: n, f0: refF0, B: B)
            let f_n = fRef_n + slope / (2 * Double.pi)
            let divisor = partialFreq(n: n, f0: 1.0, B: B)   // = n·√(1+Bn²)
            let f0_n = f_n / divisor

            // Fisher weight: n²·mag² (CRLB-optimal for equal noise floor, SNR-corrected).
            let w = Double(n * n) * state.mag * state.mag
            sumW += w
            sumWf0 += w * f0_n

            // Propagated LS uncertainty to f0: σ_{f0_n} = σ_ω / (2π · divisor).
            let sigma_f0_n = sigma_slope / (2 * Double.pi * divisor)
            if sigma_f0_n < bestSigmaF0Hz { bestSigmaF0Hz = sigma_f0_n }
        }

        guard sumW > 0 else { return nil }
        let f0Lock = sumWf0 / sumW

        // ── Octave-safety clamp (Plan 06 §6): integrator can never shift f0
        //    outside ±50 ¢ of the MPM/smoother anchor — same posture as
        //    HarmonicEstimator.maxF0ShiftCents and SpectralAnalyzer's clamp.
        let lo = anchor * pow(2, -Self.resetCents / 1200)
        let hi = anchor * pow(2,  Self.resetCents / 1200)
        guard f0Lock >= lo && f0Lock <= hi else { return nil }

        // Precision in cents: lower bound from the best single-partial LS σ.
        // With multiple partials the true combined σ is lower; the best-partial
        // figure is conservative (safe) for the UI "±X ¢" display.
        let sigmaHz = bestSigmaF0Hz.isFinite ? bestSigmaF0Hz : 1.0
        let precisionCents = max(0.001, sigmaHz / f0Lock * 1200.0 / log(2))

        return Result(f0: f0Lock, precisionCents: min(10.0, precisionCents))
    }

    /// Ordinary least-squares slope and its standard error, centred at t̄ to
    /// stay numerically clean as times grow large.
    ///
    /// Returns `(slope, sigma_slope)` in the same units as phases/times (here:
    /// rad/s). Returns `(0, ∞)` for degenerate inputs (< 2 distinct time values).
    private func lsSlope(times: [Double], phases: [Double]) -> (slope: Double, sigma: Double) {
        let k = times.count
        guard k >= 2 else { return (0, Double.infinity) }

        let tMean = times.reduce(0, +) / Double(k)
        let pMean = phases.reduce(0, +) / Double(k)

        // Centre both arrays, then use vDSP dot products for sxy and sxx.
        var dt = times.map  { $0 - tMean }
        var dp = phases.map { $0 - pMean }

        var sxy = 0.0, sxx = 0.0
        #if canImport(Accelerate)
        vDSP_dotprD(dt, 1, dp, 1, &sxy, vDSP_Length(k))
        vDSP_dotprD(dt, 1, dt, 1, &sxx, vDSP_Length(k))
        #else
        for i in 0..<k { sxy += dt[i] * dp[i]; sxx += dt[i] * dt[i] }
        #endif

        guard sxx > 0 else { return (0, Double.infinity) }
        let slope = sxy / sxx

        // Residual SSE: r[i] = dp[i] − slope·dt[i]; SSE = Σ r²
        var sse = 0.0
        #if canImport(Accelerate)
        var negSlope = -slope
        var residuals = [Double](repeating: 0, count: k)
        vDSP_vsmaD(dt, 1, &negSlope, dp, 1, &residuals, 1, vDSP_Length(k))
        vDSP_dotprD(residuals, 1, residuals, 1, &sse, vDSP_Length(k))
        #else
        for i in 0..<k { let r = dp[i] - slope * dt[i]; sse += r * r }
        #endif
        let s2 = k > 2 ? sse / Double(k - 2) : 0.0
        let sigma = (s2 / sxx).squareRoot()

        return (slope, sigma)
    }
}
