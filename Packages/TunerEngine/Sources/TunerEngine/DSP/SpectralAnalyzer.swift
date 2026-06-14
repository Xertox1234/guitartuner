import Foundation
#if canImport(Accelerate)
import Accelerate
#endif

/// The spectral core of the precision stack (Plan 06 §5.1). Provides an off-grid
/// **single-bin DTFT** and a **bias-corrected fundamental refinement** that only
/// ever *sharpens* MPM's estimate inside a narrow ±band — so it can never
/// re-introduce an octave error (MPM stays the sole octave authority, §4, §6).
///
/// P1 scope: the single-bin DTFT + the 3-sample Candan/log-parabolic refine that
/// earns the core-range gate. The full vDSP `rFFT` magnitude spectrum (for P2's
/// harmonic comb) lands when the whole spectrum is on the hot path and can be
/// structured against a tested scalar reference; here a single frame needs only a
/// handful of bins, so the exact single-bin DTFT is both sufficient and portable
/// (no Accelerate dependency, runs headless on the Linux toolchain).
enum SpectralAnalyzer {

    /// Which sub-bin estimator to use for the refine.
    enum Interp {
        /// Candan-2013 on a **rectangular**-window DFT — near-CRLB, best at mid/
        /// high bins where the negative-frequency image is far away.
        case candan
        /// Log-parabolic on a **Hann**-window magnitude — robust at low bins
        /// (the window suppresses image leakage), ~0.14 ¢ worst case.
        case logParabolicHann
        /// Log-parabolic on an already-Hann-windowed frame supplied by the caller.
        /// Use when the caller pre-computes one windowed copy shared across many
        /// `refineFundamental` calls (e.g. `HarmonicEstimator` partial loop) to
        /// avoid re-windowing N samples per partial. Semantically identical to
        /// `.logParabolicHann` but skips the internal Hann multiply.
        case logParabolicPreHanned
    }

    /// Off-grid single-bin DTFT `Σ_n frame[n]·e^{-j2π f n/fs}` (n from 0). Same
    /// convention as `StrobePhase.bin`; magnitudes and inter-bin phase ratios are
    /// what the interpolators consume. Uses a **complex-oscillator recurrence**
    /// (rotate the phasor by `−w` each sample) so there are no per-sample `cos`/
    /// `sin` calls — `refineFundamental` evaluates several bins per frame on the
    /// real-time hot path. The value is the direct sum to ~12 digits.
    static func dft(_ frame: [Float], frequency f: Double, sampleRate fs: Double) -> (re: Double, im: Double) {
        let w = 2 * Double.pi * f / fs
        let cw = cos(w), sw = sin(w)
        var cn = 1.0, sn = 0.0          // (cos wn, sin wn), n = 0
        var re = 0.0, im = 0.0
        for n in 0..<frame.count {
            let x = Double(frame[n])
            re += x * cn
            im -= x * sn
            let c2 = cn * cw - sn * sw  // advance to n+1
            sn = sn * cw + cn * sw
            cn = c2
        }
        return (re, im)
    }

    static func magnitude(_ frame: [Float], frequency f: Double, sampleRate fs: Double) -> Double {
        let c = dft(frame, frequency: f, sampleRate: fs)
        return (c.re * c.re + c.im * c.im).squareRoot()
    }

    /// Bias-corrected estimate of the fundamental, searched only within
    /// `maxCents` of MPM's `f0` (octave-safe). Returns `f0` unchanged when the
    /// expected bin isn't a clean local peak (weak/missing fundamental, silence)
    /// — i.e. the refine *defers* to MPM rather than guessing.
    static func refineFundamental(
        _ frame: [Float], near f0: Double, sampleRate fs: Double,
        interp: Interp = .candan, maxCents: Double = 50
    ) -> Double {
        let N = frame.count
        guard f0 > 0, N >= 16 else { return f0 }
        let bin = f0 * Double(N) / fs
        let k = Int(bin.rounded())
        guard k >= 2, k <= N / 2 - 2 else { return f0 }   // 5-bin window valid, below Nyquist
        let df = fs / Double(N)

        // Candan needs the rectangular transform; log-parabolic wants Hann.
        // `.logParabolicHann` windows internally (one allocation per call).
        // `.logParabolicPreHanned` skips the multiply — caller owns the copy.
        let source: [Float]
        if interp == .logParabolicHann {
            var wf = frame
            let win = Windowing.hann(N)
            #if canImport(Accelerate)
            vDSP_vmul(wf, 1, win, 1, &wf, 1, vDSP_Length(N))
            #else
            for i in 0..<N { wf[i] *= win[i] }
            #endif
            source = wf
        } else {
            source = frame  // both .candan and .logParabolicPreHanned read raw/pre-hanned frame
        }
        // Complex bins k-2…k+2, then find the actual local-peak bin among k-1…k+1
        // (the rounded seed can sit a bin off the true peak near a boundary).
        var bins: [(re: Double, im: Double)] = []
        bins.reserveCapacity(5)
        for j in (k - 2)...(k + 2) { bins.append(dft(source, frequency: Double(j) * df, sampleRate: fs)) }
        let mag2 = bins.map { $0.re * $0.re + $0.im * $0.im }
        var pi = 1
        for i in [2, 3] where mag2[i] > mag2[pi] { pi = i }
        guard mag2[pi] > 0, mag2[pi] >= mag2[pi - 1], mag2[pi] >= mag2[pi + 1] else { return f0 }

        let delta: Double
        switch interp {
        case .candan:
            delta = FrequencyInterpolator.candan(bins[pi - 1], bins[pi], bins[pi + 1], n: N)
        case .logParabolicHann, .logParabolicPreHanned:
            delta = FrequencyInterpolator.logParabolic(mag2[pi - 1], mag2[pi], mag2[pi + 1])
        }

        let refined = (Double(k - 2 + pi) + delta) * df
        // Octave-safe clamp: the refine may only nudge within ±maxCents of MPM.
        let lo = f0 * pow(2, -maxCents / 1200), hi = f0 * pow(2, maxCents / 1200)
        return min(hi, max(lo, refined))
    }
}
