import Foundation

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
    }

    /// Off-grid single-bin DTFT `Σ_n frame[n]·e^{-j2π f n/fs}` (n from 0). Same
    /// convention as `StrobePhase.bin`; magnitudes and inter-bin phase ratios are
    /// what the interpolators consume.
    static func dft(_ frame: [Float], frequency f: Double, sampleRate fs: Double) -> (re: Double, im: Double) {
        let w = 2 * Double.pi * f / fs
        var re = 0.0, im = 0.0
        for n in 0..<frame.count {
            let a = w * Double(n)
            let s = Double(frame[n])
            re += s * cos(a)
            im -= s * sin(a)
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

        // Candan needs the rectangular transform; log-parabolic wants the Hann one.
        var f2 = frame
        if interp == .logParabolicHann {
            let win = Windowing.hann(N)
            for i in 0..<N { f2[i] *= win[i] }
        }
        // Complex bins k-2…k+2, then find the actual local-peak bin among k-1…k+1
        // (the rounded seed can sit a bin off the true peak near a boundary).
        var bins: [(re: Double, im: Double)] = []
        bins.reserveCapacity(5)
        for j in (k - 2)...(k + 2) { bins.append(dft(f2, frequency: Double(j) * df, sampleRate: fs)) }
        let mag2 = bins.map { $0.re * $0.re + $0.im * $0.im }
        var pi = 1
        for i in [2, 3] where mag2[i] > mag2[pi] { pi = i }
        guard mag2[pi] > 0, mag2[pi] >= mag2[pi - 1], mag2[pi] >= mag2[pi + 1] else { return f0 }

        let delta: Double
        switch interp {
        case .candan:           delta = FrequencyInterpolator.candan(bins[pi - 1], bins[pi], bins[pi + 1], n: N)
        case .logParabolicHann: delta = FrequencyInterpolator.logParabolic(mag2[pi - 1], mag2[pi], mag2[pi + 1])
        }

        let refined = (Double(k - 2 + pi) + delta) * df
        // Octave-safe clamp: the refine may only nudge within ±maxCents of MPM.
        let lo = f0 * pow(2, -maxCents / 1200), hi = f0 * pow(2, maxCents / 1200)
        return min(hi, max(lo, refined))
    }
}
