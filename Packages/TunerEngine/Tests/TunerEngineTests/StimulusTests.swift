import Testing
@testable import TunerEngine

/// Guards the P0 stimulus families (weak/missing fundamental, vibrato/FM,
/// decay-glide) through the full pipeline — preprocessor, adaptive windowing,
/// smoothing included — so regressions in integration between stress stimuli
/// and the pipeline are caught, not just detector-level behaviour.
@Suite struct StimulusTests {
    let fs = 48_000.0

    private func mag(_ x: [Float], _ f: Double) -> Double {
        let (re, im) = StrobePhase.bin(x, frequency: f, sampleRate: fs)
        return (re * re + im * im).squareRoot()
    }

    private func runPipeline(_ signal: [Float]) -> [PitchReading] {
        let pipeline = PitchPipeline(sampleRate: fs, a4: 440, method: .mpm)
        let block = 480
        var out: [PitchReading] = []
        var i = 0
        while i < signal.count {
            let end = min(i + block, signal.count)
            out.append(contentsOf: pipeline.process(Array(signal[i..<end])))
            i = end
        }
        return out
    }

    // MARK: weak / missing fundamental

    @Test func weakAndMissingFundamentalAttenuateOnlyTheFundamental() {
        let f0 = 82.41   // E2
        let strong = Synth.inharmonicString(fundamental: f0, sampleRate: fs, seconds: 0.5, fundamentalLevel: 1)
        let weak   = Synth.inharmonicString(fundamental: f0, sampleRate: fs, seconds: 0.5, fundamentalLevel: 0.15)
        let gone   = Synth.inharmonicString(fundamental: f0, sampleRate: fs, seconds: 0.5, fundamentalLevel: 0)
        let win = 8192
        let s = Array(strong.prefix(win)), w = Array(weak.prefix(win)), g = Array(gone.prefix(win))

        // Fundamental energy: strong > weak > ~missing, monotonically.
        #expect(mag(s, f0) > mag(w, f0))
        #expect(mag(w, f0) > mag(g, f0))
        #expect(mag(g, f0) < 0.05 * mag(s, f0))   // "missing" really is gone

        // The 2nd partial is untouched — only k=1 is scaled.
        let f2 = 2 * f0 * (1 + 3e-4 * 4).squareRoot()
        #expect(abs(mag(g, f2) - mag(s, f2)) < 0.15 * mag(s, f2))
    }

    // MARK: vibrato (FM) — routed through the full pipeline

    @Test func vibratoSwingsAroundCentre() throws {
        let f0 = 196.0   // G3
        let vib = Synth.vibrato(centerFrequency: f0, sampleRate: fs, seconds: 0.6,
                                depthCents: 30, rateHz: 5.5, partials: 6)
        let readings = runPipeline(vib)
        let steady = readings.filter { $0.timestamp >= 0.2 }
        #expect(steady.count > 5, "pipeline should produce steady readings through vibrato")
        let cents = steady.map { ErrorStats.centsError(estimate: $0.frequency, truth: f0) }
        let mean = cents.reduce(0, +) / Double(cents.count)
        let spread = (cents.max() ?? 0) - (cents.min() ?? 0)
        // Pipeline smoothing reduces spread slightly vs the raw detector; 10¢ is
        // enough to confirm the FM is visible end-to-end (depthCents: 30).
        #expect(spread > 10, "FM should remain visible through pipeline smoothing")
        #expect(abs(mean) < 20, "vibrato should average to the centre frequency")
        #expect(cents.allSatisfy { abs($0) < 120 }, "no octave error under vibrato")
    }

    // MARK: decay-glide — starts sharp, settles to the true pitch

    /// Phase-slope frequency at `start` — locks the fundamental partial directly,
    /// bypassing MPM, so the glide's instantaneous pitch is observable independent
    /// of the pipeline. Used only to verify the stimulus generator is correct.
    private func phaseSlopeFreq(_ buf: [Float], start: Int, base: Double,
                                hop: Int = 512, win: Int = 4096) -> Double {
        StrobePhase.refineFrequency(
            current: Array(buf[start..<start + win]),
            previous: Array(buf[start - hop..<start - hop + win]),
            frequency: base, sampleRate: fs, hop: hop)
    }

    @Test func decayGlideStartsSharpAndSettles() throws {
        let settled = 110.0   // A2
        let buf = Synth.decayGlide(settledFrequency: settled, sampleRate: fs, seconds: 2.0,
                                   glideCents: 20, glideTau: 0.6)

        // Verify the stimulus: early reads sharp, late reads near the true pitch.
        let earlyCents = ErrorStats.centsError(
            estimate: phaseSlopeFreq(buf, start: 512, base: settled), truth: settled)
        #expect(earlyCents > 10, "glide should start sharp")

        let lateCents = ErrorStats.centsError(
            estimate: phaseSlopeFreq(buf, start: Int(1.7 * fs), base: settled), truth: settled)
        #expect(abs(lateCents) < 3, "phase slope should be near true pitch after settling")
        #expect(earlyCents > lateCents + 8, "glide should actually settle")

        // After settling, the full pipeline (not just the detector) reads the
        // correct pitch with no octave error.
        let settledBuf = Array(buf.suffix(from: Int(1.5 * fs)))
        let readings = runPipeline(settledBuf)
        let last = try #require(readings.last)
        #expect(abs(ErrorStats.centsError(estimate: last.frequency, truth: settled)) < 3.0,
                "pipeline should settle to the true pitch after glide")
    }
}
