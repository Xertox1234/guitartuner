import Foundation

/// Single-bin DFT phase work: the **strobe phase** (the signature visual) and a
/// **phase-vocoder** instantaneous-frequency refinement (sub-cent). One idea, two
/// payoffs — "the accuracy work and the signature visual are the same work"
/// (DESIGN §3).
///
/// ### Strobe phase (the contract)
/// `phase` is a normalised **0…1 cycle position** of the fundamental measured
/// against a reference oscillator at the **nearest equal-tempered note**. We take
/// the signal's phase at the reference frequency, referenced to the *global
/// sample clock*. On pitch that phase is constant across hops → the strobe stands
/// still; off pitch it advances at the **beat rate** (∝ the Hz error) — sharp one
/// way, flat the other. The renderer scrolls by Δphase between readings, which is
/// exactly a true strobe (vs. the prototype's cents-derived approximation).
///
/// ### Instantaneous frequency (sub-cent)
/// For two frames `hop` samples apart, a pure tone at the analysis frequency
/// advances by `2π·f·hop/fs`. The *excess* measured phase advance is the
/// frequency error, so `f_inst = f + fs·princarg(Δφ − 2π·f·hop/fs)/(2π·hop)`.
enum StrobePhase {

    /// Complex single-bin DFT `Σ_k frame[k]·e^{-jθk}`, θ = 2π·f·k/fs. Uses a
    /// complex-oscillator recurrence (same as SpectralAnalyzer.dft) — two cos/sin
    /// calls at setup, then multiply-adds, no per-sample transcendentals.
    static func bin(_ frame: [Float], frequency f: Double, sampleRate fs: Double) -> (re: Double, im: Double) {
        let w = 2 * Double.pi * f / fs
        let cw = cos(w), sw = sin(w)
        var cn = 1.0, sn = 0.0          // (cos wk, sin wk), k = 0
        var re = 0.0, im = 0.0
        for k in 0..<frame.count {
            let x = Double(frame[k])
            re += x * cn
            im -= x * sn
            let c2 = cn * cw - sn * sw  // advance phasor to k+1
            sn = sn * cw + cn * sw
            cn = c2
        }
        return (re, im)
    }

    /// Strobe phase ∈ [0, 1) of `frame` at `referenceFrequency`, referenced to the
    /// global clock so it's stationary when the input matches the reference.
    /// `globalStart` is the absolute sample index of `frame[0]`.
    ///
    /// Increasing phase ⇒ sharp (the app maps that to "scroll →"); the value wraps
    /// at 1. Returns `nil` for a non-positive reference.
    static func phase(
        _ frame: [Float],
        referenceFrequency fRef: Double,
        sampleRate fs: Double,
        globalStart: Int
    ) -> Double? {
        guard fRef > 0 else { return nil }
        let (re, im) = bin(frame, frequency: fRef, sampleRate: fs)
        let localCycles = atan2(im, re) / (2 * Double.pi)
        // Reduce the global rotation mod 1 *before* the trig-free subtraction to
        // keep precision over a long session (globalStart grows unbounded).
        let g = fRef * Double(globalStart) / fs
        let gFrac = g - g.rounded(.down)
        var p = localCycles - gFrac
        p -= p.rounded(.down)             // → [0, 1)
        return p
    }

    /// Phase-vocoder refinement. `current` and `previous` are equal-length frames
    /// whose starts are exactly `hop` samples apart (previous earlier). Returns the
    /// instantaneous frequency, with the correction clamped to ±`maxCents` of `f`
    /// so a noisy phase can never cause an octave jump.
    static func refineFrequency(
        current: [Float],
        previous: [Float],
        frequency f: Double,
        sampleRate fs: Double,
        hop: Int,
        maxCents: Double = 35
    ) -> Double {
        guard f > 0, hop > 0, current.count == previous.count else { return f }
        let now = bin(current, frequency: f, sampleRate: fs)
        let then = bin(previous, frequency: f, sampleRate: fs)
        let phaseNow = atan2(now.im, now.re)
        let phasePrev = atan2(then.im, then.re)
        let expected = 2 * Double.pi * f * Double(hop) / fs
        let residual = princarg(phaseNow - phasePrev - expected)
        let delta = fs * residual / (2 * Double.pi * Double(hop))   // Hz correction
        // Clamp to ±maxCents so phase noise can't move us a semitone+.
        let maxDelta = f * (pow(2, maxCents / 1200) - 1)
        let clamped = max(-maxDelta, min(maxDelta, delta))
        return f + clamped
    }

    /// Wrap to (−π, π].
    @inline(__always) static func princarg(_ x: Double) -> Double {
        var p = x.truncatingRemainder(dividingBy: 2 * Double.pi)
        if p > .pi { p -= 2 * Double.pi }
        if p <= -.pi { p += 2 * Double.pi }
        return p
    }
}
