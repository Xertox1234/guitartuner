import Foundation
#if canImport(Accelerate)
import Accelerate
#endif

/// The capture-agnostic DSP pipeline: push samples (from live audio, a file, or a
/// synthesizer), get `PitchReading`s. Synchronous and deterministic — **this** is
/// the unit the tests and the benchmark drive headlessly, with no audio engine or
/// concurrency in the way (Plan 01 §1, CI note). The `TunerEngine` actor wraps it
/// for live use.
///
/// Per analysis hop:
/// ```
/// preprocess (DC block + HPF) → window (Hann) → MPM/YIN fundamental
///   → phase-vocoder refine (sub-cent) → median+EMA smoothing
///   → confidence + sustain gate → note + cents + strobe phase
/// ```
public final class PitchPipeline {
    public let sampleRate: Double
    public var a4: Double {
        didSet { a4 = min(Pitch.maxA4, max(Pitch.minA4, a4)) }
    }
    /// Fundamental-tracking algorithm (benchmark-selected default).
    public var method: DetectionMethod
    /// Optional string-lock hint: when set, the strobe references this note (and
    /// gating can be tightened) instead of the chromatic nearest note.
    public var targetNote: Note?

    /// The full guitar+bass search range (below low B to high frets).
    public static let searchRange: ClosedRange<Double> = 27...1400

    /// At/above this fundamental the core range uses the bias-corrected spectral
    /// refine (Plan 06 P1); below it the fundamental bin is too low for a clean
    /// single-frame spectral peak (the negative-frequency image leaks in), so bass
    /// stays on the phase-vocoder until P2's harmonic comb. Tunable in one place.
    static let spectralRefineMinHz: Double = 120

    // Rolling, preprocessed analysis buffer (circular, capacity = longest window).
    private let cap = AnalysisConfig.maxWindow
    private var ring: [Float]
    private var head = 0          // next write position
    private var filled = 0        // valid samples in `ring`
    private var totalSamples = 0  // absolute count of preprocessed samples

    private var preproc: Preprocessor
    private var smoother = FrequencySmoother()
    // Gate margin sits below clean clarity (~0.95) and inharmonic-low clarity
    // (~0.7–0.85 on raw frames) but above noise (~0.3–0.5).
    private var gate = SustainGate(minConfidence: 0.6)
    private var hannCache: [Int: [Float]] = [:]      // per-instance window cache
    private var config: AnalysisConfig = .acquire
    private var lastAnalyzedAt = 0
    private var trackedFrequency: Double?      // last confident estimate (band + reset)
    private var unvoicedStreak = 0

    // Phase-vocoder history (previous windowed frame + its geometry).
    private var prevFrame: [Float]?
    private var prevFrameStart = 0
    private var prevWindow = 0
    private var prevHop = 0

    private let emitFloor: Double = 0.5        // clarity below this = unvoiced

    public init(
        sampleRate: Double = 48_000,
        a4: Double = Pitch.standardA4,
        method: DetectionMethod = .mpm,
        targetNote: Note? = nil
    ) {
        self.sampleRate = sampleRate
        self.a4 = a4
        self.method = method
        self.targetNote = targetNote
        self.preproc = Preprocessor(sampleRate: sampleRate)
        self.ring = [Float](repeating: 0, count: cap)
    }

    /// Push samples; returns any readings produced this call. Safe with any chunk
    /// size — samples are folded in one at a time and analysis fires on hop
    /// boundaries, so cadence is independent of how the caller blocks the audio.
    @discardableResult
    public func process(_ samples: [Float]) -> [PitchReading] {
        var out: [PitchReading] = []
        for raw in samples {
            let s = preproc.process(raw)
            ring[head] = s
            head = (head + 1) % cap
            if filled < cap { filled += 1 }
            totalSamples += 1

            if totalSamples - lastAnalyzedAt >= config.hop, filled >= config.window {
                lastAnalyzedAt = totalSamples
                if let reading = analyze() { out.append(reading) }
            }
        }
        return out
    }

    /// Clear all state (call on stop / input change).
    public func reset() {
        head = 0; filled = 0; totalSamples = 0; lastAnalyzedAt = 0
        preproc.reset(); smoother.reset(); gate.reset()
        config = .acquire; trackedFrequency = nil; unvoicedStreak = 0
        prevFrame = nil
        for i in ring.indices { ring[i] = 0 }
    }

    // MARK: - One hop

    private func analyze() -> PitchReading? {
        let window = config.window
        let frameStart = totalSamples - window
        // Raw frame for the time-domain detectors + phase-vocoder: NSDF/YIN want
        // the *periods*, and a Hann taper roughly halves the effective period
        // count — enough to drop low/inharmonic clarity below the gate. (The
        // strobe-phase single-bin DFT gets a windowed copy below, for clean phase.)
        let frame = recent(window)

        guard let det = PitchDetector.detect(
            frame, sampleRate: sampleRate, range: Self.searchRange, method: method
        ), det.clarity >= emitFloor else {
            return handleUnvoiced()
        }

        unvoicedStreak = 0

        // Sub-cent refinement. Two paths, never touching the octave (MPM anchor):
        //
        // Mid/High (≥120 Hz) — P1 Candan spectral refine: bias-corrected single-
        // frame estimate, near-CRLB for the fundamental bin. Already earns ≤0.1 ¢.
        //
        // Bass (<120 Hz) — P2 harmonic comb estimator: locates all audible partials,
        // jointly fits (f0, B) via (fₙ/n)² regression, Fisher-fuses. This is where
        // the bass 2.96 ¢ → ≤1 ¢ win comes from (Plan 06 §5.3). Falls back to the
        // phase-vocoder if the harmonic fit returns nil (weak signal, cold frame).
        var frequency = det.frequency
        var harmonicB: Double? = nil

        if det.frequency >= Self.spectralRefineMinHz {
            // P1: bias-corrected spectral refine for mid/high.
            frequency = SpectralAnalyzer.refineFundamental(
                frame, near: det.frequency, sampleRate: sampleRate, interp: .candan, maxCents: 50
            )
        } else if let result = HarmonicEstimator.refine(
            frame, near: det.frequency, sampleRate: sampleRate
        ) {
            // P2: harmonic comb — primary bass path.
            frequency = result.frequency
            harmonicB = result.inharmonicityB
        } else if let prev = prevFrame,
                  prevWindow == window, prevHop == config.hop,
                  prevFrameStart == frameStart - config.hop {
            // Fallback: phase-vocoder (used when harmonic fit fails on weak/cold frames).
            frequency = StrobePhase.refineFrequency(
                current: frame, previous: prev,
                frequency: det.frequency, sampleRate: sampleRate, hop: config.hop
            )
        }

        // Smooth in the log domain.
        let smoothed = smoother.update(frequency: frequency, a4: a4)
        guard let (nearest, cents) = Pitch.nearest(frequency: smoothed, a4: a4) else {
            return handleUnvoiced()
        }

        // Strobe phase against the reference (string-lock target or nearest note).
        // Window a copy here to suppress spectral leakage from neighbouring partials.
        var phaseFrame = frame
        applyHann(&phaseFrame)
        let reference = (targetNote ?? nearest).frequency(a4: a4)
        let phase = StrobePhase.phase(
            phaseFrame, referenceFrequency: reference, sampleRate: sampleRate, globalStart: frameStart
        ) ?? 0

        // Sustain gate + confidence.
        let (emit, _) = gate.step(confidence: det.clarity)

        // Remember geometry for the next phase-vocoder step and band selection.
        prevFrame = frame
        prevFrameStart = frameStart
        prevWindow = window
        prevHop = config.hop
        trackedFrequency = smoothed
        config = nextConfig(for: smoothed)

        guard emit else { return nil }

        // Timestamp = centre of the analysed window, in seconds.
        let timestamp = (Double(frameStart) + Double(window) / 2) / sampleRate
        return PitchReading(
            frequency: smoothed,
            note: nearest,
            cents: cents,
            confidence: det.clarity,
            phase: phase,
            timestamp: timestamp,
            inharmonicityB: harmonicB
        )
    }

    private func handleUnvoiced() -> PitchReading? {
        _ = gate.step(confidence: 0)
        unvoicedStreak += 1
        // After sustained silence, forget the note so the next pluck acquires
        // fresh (long window, no stale smoothing) and the strobe doesn't drift.
        if unvoicedStreak >= 8 {
            smoother.reset()
            trackedFrequency = nil
            config = .acquire
            prevFrame = nil
        }
        return nil
    }

    // MARK: - Helpers

    /// The most recent `n` preprocessed samples, in chronological order.
    private func recent(_ n: Int) -> [Float] {
        var out = [Float](repeating: 0, count: n)
        let start = (head - n + cap) % cap
        for i in 0..<n {
            out[i] = ring[(start + i) % cap]
        }
        return out
    }

    private func applyHann(_ frame: inout [Float]) {
        let n = frame.count
        let w: [Float]
        if let cached = hannCache[n] { w = cached }
        else { w = Windowing.hann(n); hannCache[n] = w }
        #if canImport(Accelerate)
        vDSP_vmul(frame, 1, w, 1, &frame, 1, vDSP_Length(n))
        #else
        for i in frame.indices { frame[i] *= w[i] }
        #endif
    }

    /// Band selection with hysteresis so we don't chatter at the boundaries.
    private func nextConfig(for f0: Double) -> AnalysisConfig {
        let hmLo = AnalysisConfig.highMidHz - AnalysisConfig.highMidHysteresis  // 235
        let hmHi = AnalysisConfig.highMidHz + AnalysisConfig.highMidHysteresis  // 265
        let mlLo = AnalysisConfig.midLowHz  - AnalysisConfig.midLowHysteresis   // 110
        let mlHi = AnalysisConfig.midLowHz  + AnalysisConfig.midLowHysteresis   // 130
        switch config.label {
        case "high": return f0 < hmLo ? AnalysisConfig.band(forFrequency: f0) : .high
        case "mid":
            if f0 >= hmHi { return .high }
            if f0 < mlLo  { return .low }
            return .mid
        case "low": return f0 >= mlHi ? AnalysisConfig.band(forFrequency: f0) : .low
        default: return AnalysisConfig.band(forFrequency: f0)   // acquire → settle
        }
    }
}
