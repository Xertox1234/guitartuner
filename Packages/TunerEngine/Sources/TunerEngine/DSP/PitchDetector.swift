import Foundation

/// Which fundamental-tracking algorithm the engine runs. Both track the
/// *fundamental* (not the tallest FFT peak), which matters because real strings
/// are slightly **inharmonic** — partials sit a touch sharp of integer multiples,
/// so spectral-peak methods bias sharp on exactly the notes we care about
/// (DESIGN §3). The benchmark decides the default.
public enum DetectionMethod: String, Sendable, CaseIterable {
    /// McLeod Pitch Method via the NSDF. Naturally octave-safe.
    case mpm
    /// YIN cumulative-mean-normalised difference.
    case yin
    /// MPM, cross-checked against YIN to break low-confidence / octave ties.
    case hybrid
}

/// One detector estimate. `clarity` ∈ 0…1 is the periodicity confidence
/// (NSDF peak height for MPM, 1−d′ for YIN); the pipeline gates on it.
struct DetectorResult: Equatable {
    let frequency: Double   // Hz
    let period: Double      // samples (sub-sample, parabolically refined)
    let clarity: Double     // 0…1
    let method: DetectionMethod
}

/// Stateless fundamental-frequency estimators. Feed a (windowed) frame and the
/// search range; get back the fundamental + a clarity score.
enum PitchDetector {

    /// McLeod / YIN / hybrid on one frame. Returns `nil` if nothing periodic is
    /// in range (silence, noise). `range` clamps the candidate frequencies.
    static func detect(
        _ frame: [Float],
        sampleRate: Double,
        range: ClosedRange<Double>,
        method: DetectionMethod,
        emitFloor: Double = AnalysisConfig.emitFloor
    ) -> DetectorResult? {
        let n = frame.count
        guard n >= 64 else { return nil }

        // Lag search bounds from the frequency range, kept inside the window.
        let minLag = max(2, Int((sampleRate / range.upperBound).rounded(.down)))
        let maxLagWanted = Int((sampleRate / range.lowerBound).rounded(.up))
        let maxLag = min(maxLagWanted, n / 2)
        guard maxLag > minLag + 1 else { return nil }

        let corr = Correlation.compute(frame, maxLag: maxLag)

        // Reject silence: lag-0 energy must clear a tiny floor.
        guard corr.prefixEnergy[n] > 1e-7 else { return nil }

        switch method {
        case .mpm:
            return mpm(corr, sampleRate: sampleRate, minLag: minLag, maxLag: maxLag)
        case .yin:
            return yin(corr, sampleRate: sampleRate, minLag: minLag, maxLag: maxLag)
        case .hybrid:
            return hybrid(corr, sampleRate: sampleRate, minLag: minLag, maxLag: maxLag, emitFloor: emitFloor)
        }
    }

    // MARK: McLeod Pitch Method (NSDF)

    static func mpm(
        _ corr: Correlation,
        sampleRate: Double,
        minLag: Int,
        maxLag: Int
    ) -> DetectorResult? {
        // Collect "key maxima": the peak in each positive lobe of the NSDF.
        var maxima: [(tau: Int, value: Double)] = []
        var tau = 1
        // Descend past the τ≈0 lobe to the first non-positive crossing.
        while tau < maxLag, corr.nsdf(tau) > 0 { tau += 1 }
        while tau < maxLag {
            while tau < maxLag, corr.nsdf(tau) <= 0 { tau += 1 }    // into next positive lobe
            var bestTau = tau
            var bestVal = -Double.infinity
            while tau < maxLag, corr.nsdf(tau) > 0 {
                let v = corr.nsdf(tau)
                if v > bestVal { bestVal = v; bestTau = tau }
                tau += 1
            }
            if bestTau >= minLag, bestTau <= maxLag - 1, bestVal.isFinite {
                maxima.append((bestTau, bestVal))
            }
        }
        guard let nmax = maxima.map(\.value).max(), nmax > 0 else { return nil }

        // First key max clearing k·nmax — the octave-safe choice (McLeod k≈0.9).
        let k = AnalysisConfig.nsdfPeakK
        let threshold = k * nmax
        let chosen = maxima.first { $0.value >= threshold } ?? maxima.max { $0.value < $1.value }!

        let (offset, peak) = parabolicVertex(
            corr.nsdf(chosen.tau - 1), corr.nsdf(chosen.tau), corr.nsdf(chosen.tau + 1)
        )
        let period = Double(chosen.tau) + offset
        guard period > 0 else { return nil }
        return DetectorResult(
            frequency: sampleRate / period,
            period: period,
            clarity: max(0, min(1, peak)),
            method: .mpm
        )
    }

    // MARK: YIN

    static func yin(
        _ corr: Correlation,
        sampleRate: Double,
        minLag: Int,
        maxLag: Int,
        threshold: Double = 0.12
    ) -> DetectorResult? {
        // Cumulative-mean-normalised difference d′(τ).
        var dprime = [Double](repeating: 1, count: maxLag + 1)
        var runningSum = 0.0
        for t in 1...maxLag {
            let d = corr.yinDifference(t)
            runningSum += d
            dprime[t] = runningSum > 1e-12 ? d * Double(t) / runningSum : 1
        }

        // First local minimum below the absolute threshold within range…
        var chosen = -1
        var t = max(minLag, 1)
        while t < maxLag {
            if dprime[t] < threshold {
                while t + 1 < maxLag, dprime[t + 1] < dprime[t] { t += 1 }  // descend to the dip
                chosen = t
                break
            }
            t += 1
        }
        // …else the global minimum in range (still report, low confidence).
        if chosen < 0 {
            var best = minLag
            for tt in minLag...(maxLag - 1) where dprime[tt] < dprime[best] { best = tt }
            chosen = best
        }
        guard chosen >= 1, chosen <= maxLag - 1 else { return nil }

        let (offset, _) = parabolicVertex(dprime[chosen - 1], dprime[chosen], dprime[chosen + 1])
        let period = Double(chosen) + offset
        guard period > 0 else { return nil }
        return DetectorResult(
            frequency: sampleRate / period,
            period: period,
            clarity: max(0, min(1, 1 - dprime[chosen])),
            method: .yin
        )
    }

    // MARK: Hybrid

    /// MPM is the primary (octave-safe); YIN breaks ties when MPM is unsure or
    /// the two disagree by ~an octave — then prefer the lower (fundamental).
    static func hybrid(
        _ corr: Correlation,
        sampleRate: Double,
        minLag: Int,
        maxLag: Int,
        emitFloor: Double = AnalysisConfig.emitFloor
    ) -> DetectorResult? {
        let m = mpm(corr, sampleRate: sampleRate, minLag: minLag, maxLag: maxLag)
        let y = yin(corr, sampleRate: sampleRate, minLag: minLag, maxLag: maxLag)
        guard let m else { return y.map { relabel($0, .hybrid) } }
        guard let y else { return relabel(m, .hybrid) }

        let ratio = m.frequency / y.frequency
        let octaveApart = abs(ratio - 2) < 0.06 || abs(ratio - 0.5) < 0.03
        if octaveApart {
            // Trust the lower fundamental if it's reasonably clear.
            let lower = m.frequency < y.frequency ? m : y
            let higher = m.frequency < y.frequency ? y : m
            // NOTE: emitFloor is reused here as the octave-rescue clarity bar
            // (picking the lower/fundamental candidate). It equals the pipeline
            // emit gate today (default 0.5). When the deferred bass-fix raises a
            // per-instrument emitFloor for noise rejection, raising it ALSO makes
            // this branch favor the higher (octave) candidate — a latent trade
            // against the CI-gated 0.00% octave-error spec. Decide there whether
            // the octave-rescue bar should decouple from emitFloor.
            // (docs/todos/P1-bass-detection-policy-tuning.md)
            let pick = lower.clarity > emitFloor ? lower : higher
            return relabel(pick, .hybrid)
        }
        // Agree → keep MPM's value but average the clarity for a fair score.
        return DetectorResult(
            frequency: m.frequency,
            period: m.period,
            clarity: max(0, min(1, 0.5 * (m.clarity + y.clarity))),
            method: .hybrid
        )
    }

    private static func relabel(_ r: DetectorResult, _ method: DetectionMethod) -> DetectorResult {
        DetectorResult(frequency: r.frequency, period: r.period, clarity: r.clarity, method: method)
    }
}
