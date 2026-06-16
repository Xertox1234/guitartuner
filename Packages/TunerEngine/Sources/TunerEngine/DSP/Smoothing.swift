import Foundation

/// Short **median + EMA** smoother working in the log-frequency (MIDI) domain so
/// it's musically uniform across the range. The median kills single-frame
/// outliers (octave glitches, pluck-transient blips); the EMA removes residual
/// jitter without perceptible lag (DESIGN §3). A large jump (note change) snaps
/// rather than drags, so switching strings feels instant.
struct FrequencySmoother {
    private var window: [Double] = []          // recent MIDI values
    private var ema: Double?                    // smoothed MIDI value
    private let medianCount: Int
    private let alpha: Double
    private let snapCents: Double

    /// - medianCount: odd window length for the median (5 ≈ 3 hops of lag).
    /// - alpha: EMA factor (higher = snappier, noisier).
    /// - snapCents: jumps larger than this bypass smoothing (new note).
    init(medianCount: Int = 5, alpha: Double = AnalysisConfig.smoothingAlpha, snapCents: Double = AnalysisConfig.smoothingSnapCents) {
        self.medianCount = max(1, medianCount | 1)   // force odd
        self.alpha = alpha
        self.snapCents = snapCents
    }

    /// Feed an instantaneous frequency, get the smoothed frequency.
    mutating func update(frequency f: Double, a4: Double) -> Double {
        let midi = Pitch.midi(frequency: f, a4: a4)

        window.append(midi)
        if window.count > medianCount { window.removeFirst() }
        let med = Self.median(window)

        if let prev = ema, abs(med - prev) * 100 > snapCents {
            // Big jump → new note: reset both stages so we don't lag the change.
            window = [midi]
            ema = midi
        } else if let prev = ema {
            ema = prev + alpha * (med - prev)
        } else {
            ema = med
        }

        return Pitch.frequency(midi: ema ?? med, a4: a4)
    }

    mutating func reset() {
        window.removeAll(keepingCapacity: true)
        ema = nil
    }

    static func median(_ xs: [Double]) -> Double {
        guard !xs.isEmpty else { return 0 }
        let s = xs.sorted()
        return s[s.count / 2]
    }
}

/// Confidence + **sustain gate**: pluck attacks are noisy transients, so we wait
/// for a few consecutive confident frames before declaring a stable reading, and
/// we drop back to "acquiring" when confidence collapses (note released / muted).
/// This is what lets the strobe lock onto the steady sustain, not the attack
/// (DESIGN §3).
struct SustainGate {
    private var confidentStreak = 0
    private let minConfidence: Double
    private let sustainFrames: Int

    /// - minConfidence: clarity floor to count a frame as voiced.
    /// - sustainFrames: consecutive voiced frames required to call it stable.
    init(minConfidence: Double = AnalysisConfig.sustainMinConfidence, sustainFrames: Int = 3) {
        self.minConfidence = minConfidence
        self.sustainFrames = sustainFrames
    }

    /// Returns whether to emit this frame and whether it's reached stable sustain.
    /// We emit voiced frames immediately (so the UI fades in) but only mark
    /// `stable` once the streak clears — callers can gate "locked" on `stable`.
    mutating func step(confidence: Double) -> (emit: Bool, stable: Bool) {
        if confidence >= minConfidence {
            confidentStreak = min(confidentStreak + 1, sustainFrames * 4)
            return (true, confidentStreak >= sustainFrames)
        } else {
            confidentStreak = 0
            return (false, false)
        }
    }

    mutating func reset() { confidentStreak = 0 }
}
