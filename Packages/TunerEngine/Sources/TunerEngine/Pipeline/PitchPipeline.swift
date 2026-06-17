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

    /// Maximum per-estimate ±σ for `isLockIntegrated` to engage (Plan 06 P4 §7.2).
    // Rolling, preprocessed analysis buffer (circular, capacity = longest window).
    private let cap = AnalysisConfig.maxWindow
    private var ring: [Float]
    private var head = 0          // next write position
    private var filled = 0        // valid samples in `ring`
    private var totalSamples = 0  // absolute count of preprocessed samples

    /// Active per-instrument detection policy (default = full-range = legacy).
    public var policy: DetectionPolicy
    private var preproc: Preprocessor
    private var smoother: FrequencySmoother
    private var gate = SustainGate()
    private var hannCache: [Int: [Float]] = [:]      // per-instance window cache
    private var config: BandSpec
    private var lastAnalyzedAt = 0
    private var trackedFrequency: Double?      // last confident estimate (band + reset)
    private var unvoicedStreak = 0

    // Phase-vocoder history (previous windowed frame + its geometry).
    private var prevFrame: [Float]?
    private var prevFrameStart = 0
    private var prevWindow = 0
    private var prevHop = 0

    private var phaseIntegrator = PhaseIntegrator()

    public init(
        sampleRate: Double = 48_000,
        a4: Double = Pitch.standardA4,
        method: DetectionMethod = .mpm,
        targetNote: Note? = nil,
        policy: DetectionPolicy = .fullRange
    ) {
        self.sampleRate = sampleRate
        self.a4 = a4
        self.method = method
        self.targetNote = targetNote
        self.policy = policy
        self.preproc = Preprocessor(sampleRate: sampleRate)
        self.ring = [Float](repeating: 0, count: cap)
        self.smoother = FrequencySmoother(medianCount: policy.smoothingMedianCount,
                                          alpha: policy.smoothingAlpha)
        self.config = policy.acquire
    }

    /// Swap the detection policy (e.g. on instrument change). Resets smoother/gate
    /// and band state so the new geometry takes effect cleanly.
    public func setPolicy(_ newPolicy: DetectionPolicy) {
        policy = newPolicy
        smoother = FrequencySmoother(medianCount: newPolicy.smoothingMedianCount,
                                     alpha: newPolicy.smoothingAlpha)
        gate.reset()
        config = newPolicy.acquire
        trackedFrequency = nil
        prevFrame = nil
        phaseIntegrator.reset()
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
        config = policy.acquire; trackedFrequency = nil; unvoicedStreak = 0
        prevFrame = nil; phaseIntegrator.reset()
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
            frame, sampleRate: sampleRate, range: policy.searchRange,
            method: method, emitFloor: policy.emitFloor
        ), det.clarity >= policy.emitFloor else {
            return handleUnvoiced()
        }

        unvoicedStreak = 0

        // Octave-history guard — second line of defence after k·nmax peak selection.
        // If the NSDF detection jumps ≥1 octave from the tracked frequency but clarity
        // is below the high-confidence threshold, the jump is likely an alias or harmonic
        // artefact (not a genuine note change) and is treated as unvoiced.
        if let tracked = trackedFrequency,
           abs(1200 * log2(det.frequency / tracked)) >= 1200,
           det.clarity < AnalysisConfig.octaveGuardMinClarity {
            return handleUnvoiced()
        }

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

        if det.frequency >= AnalysisConfig.midLowHz {
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
        let (emit, stable) = gate.step(confidence: det.clarity, floor: config.sustainConfidence)

        // Timestamp = centre of the analysed window, in seconds.
        let timestamp = (Double(frameStart) + Double(window) / 2) / sampleRate

        // P3: Phase-slope integrator. Only runs on stable sustain; resets on drop.
        // Overrides `smoothed` with a long-window phase-slope refined estimate.
        // The smoother state is NOT updated from the integrator result.
        //
        // Always uses maxPartials=1 (the fundamental only) with B=0. Higher partials
        // require exact inharmonicity — unreliable B estimates (including fake-harmonic
        // artefacts from very low bass near the HPF cutoff) shift the DFT evaluation
        // point for n≥2, compounding via Fisher weighting. The fundamental is immune:
        // for n=1, inharmonicity affects fRef_1 by √(1+B) ≈ 1+B/2 ≈ 0.26¢ max — the
        // same systematic floor P1/P2 already have — while the long-window slope still
        // drives lock σ well below 0.1¢.
        var emittedFrequency = smoothed
        var emittedNearest = nearest
        var emittedCents = cents
        var precisionCents: Double? = nil
        var isLockIntegrated = false

        if stable {
            if let r = phaseIntegrator.feed(
                frame: frame,
                f0: smoothed,
                inharmonicityB: 0,
                sampleRate: sampleRate,
                frameTime: timestamp,
                maxPartials: 1
            ) {
                precisionCents = r.precisionCents
                // Only override the frequency estimate when the LS residuals are tight.
                // During decay-glide attack the pitch is still drifting — large residuals
                // mean the integrator's f0 is biased by the slope of the glide, so we
                // fall back to `smoothed` and leave isLockIntegrated false.
                isLockIntegrated = r.precisionCents <= AnalysisConfig.lockPrecisionThreshold
                if isLockIntegrated {
                    emittedFrequency = r.f0
                    if let (nn, nc) = Pitch.nearest(frequency: r.f0, a4: a4) {
                        emittedNearest = nn
                        emittedCents = nc
                    }
                }
            }
        } else {
            phaseIntegrator.reset()
        }

        // Remember geometry for the next phase-vocoder step and band selection.
        prevFrame = frame
        prevFrameStart = frameStart
        prevWindow = window
        prevHop = config.hop
        trackedFrequency = smoothed
        config = Self.nextBand(for: smoothed, current: config, in: policy)

        guard emit else { return nil }

        return PitchReading(
            frequency: emittedFrequency,
            note: emittedNearest,
            cents: emittedCents,
            confidence: det.clarity,
            phase: phase,
            timestamp: timestamp,
            inharmonicityB: harmonicB,
            precisionCents: precisionCents,
            isLockIntegrated: isLockIntegrated
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
            config = policy.acquire
            prevFrame = nil
            phaseIntegrator.reset()
        }
        return nil
    }

    // MARK: - Helpers

    /// The most recent `n` preprocessed samples, in chronological order.
    /// Uses two contiguous slice copies to avoid per-element modulo arithmetic.
    private func recent(_ n: Int) -> [Float] {
        var out = [Float](repeating: 0, count: n)
        let start = (head - n + cap) % cap
        if start + n <= cap {
            // Non-wrapping: one contiguous copy.
            out.replaceSubrange(0..<n, with: ring[start..<start + n])
        } else {
            // Wrapping: copy tail of ring, then head.
            let tail = cap - start
            out.replaceSubrange(0..<tail,    with: ring[start..<cap])
            out.replaceSubrange(tail..<n,    with: ring[0..<n - tail])
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

    /// Pure band-transition step (testable). Reproduces the former stateful
    /// `switch`-based selection from a flat band plan: rise one band when f0 clears
    /// the band-above floor + its hysteresis; drop (to the pure-floor band) when f0
    /// falls below the current floor − its hysteresis; else stay (anti-chatter).
    static func nextBand(for f0: Double, current: BandSpec, in policy: DetectionPolicy) -> BandSpec {
        let bands = policy.bands
        guard let i = bands.firstIndex(where: { $0.label == current.label }) else {
            return policy.band(forFrequency: f0)   // acquire / unknown → settle by lookup
        }
        if i > 0 {
            let above = bands[i - 1]
            if f0 >= above.floorHz + above.hysteresisHz { return above }
        }
        if i < bands.count - 1, f0 < current.floorHz - current.hysteresisHz {
            return policy.band(forFrequency: f0)
        }
        return current
    }
}
