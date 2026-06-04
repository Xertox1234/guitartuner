import XCTest
@testable import TunerEngine

/// Guards the P0 stimulus families (weak/missing fundamental, vibrato/FM,
/// decay-glide) behave as their scoring assumes — so the benchmark measures what
/// it claims to (Plan 06 §9).
final class StimulusTests: XCTestCase {
    let fs = 48_000.0

    /// Single-bin DFT magnitude of a frame at `f`.
    private func mag(_ x: [Float], _ f: Double) -> Double {
        let (re, im) = StrobePhase.bin(x, frequency: f, sampleRate: fs)
        return (re * re + im * im).squareRoot()
    }

    // MARK: weak / missing fundamental

    func testWeakAndMissingFundamentalAttenuateOnlyTheFundamental() {
        let f0 = 82.41   // E2
        let strong = Synth.inharmonicString(fundamental: f0, sampleRate: fs, seconds: 0.5, fundamentalLevel: 1)
        let weak   = Synth.inharmonicString(fundamental: f0, sampleRate: fs, seconds: 0.5, fundamentalLevel: 0.15)
        let gone   = Synth.inharmonicString(fundamental: f0, sampleRate: fs, seconds: 0.5, fundamentalLevel: 0)
        let win = 8192
        let s = Array(strong.prefix(win)), w = Array(weak.prefix(win)), g = Array(gone.prefix(win))

        // Fundamental energy: strong > weak > ~missing, monotonically.
        XCTAssertGreaterThan(mag(s, f0), mag(w, f0))
        XCTAssertGreaterThan(mag(w, f0), mag(g, f0))
        XCTAssertLessThan(mag(g, f0), 0.05 * mag(s, f0))   // "missing" really is gone

        // The 2nd partial is untouched — only k=1 is scaled.
        let f2 = 2 * f0 * (1 + 3e-4 * 4).squareRoot()
        XCTAssertEqual(mag(g, f2), mag(s, f2), accuracy: 0.15 * mag(s, f2))
    }

    // MARK: vibrato (FM) — the reading swings but averages to centre

    func testVibratoSwingsAroundCentre() {
        let f0 = 196.0   // G3
        let vib = Synth.vibrato(centerFrequency: f0, sampleRate: fs, seconds: 0.6,
                                depthCents: 30, rateHz: 5.5, partials: 6)
        let win = 2048, range = PitchPipeline.searchRange
        var cents: [Double] = []
        var start = 0
        while start + win <= vib.count {
            if let det = PitchDetector.detect(Array(vib[start..<start + win]), sampleRate: fs, range: range, method: .mpm) {
                cents.append(ErrorStats.centsError(estimate: det.frequency, truth: f0))
            }
            start += win
        }
        XCTAssertGreaterThan(cents.count, 8)
        let mean = cents.reduce(0, +) / Double(cents.count)
        let spread = (cents.max() ?? 0) - (cents.min() ?? 0)
        XCTAssertGreaterThan(spread, 15)                 // the FM is actually present
        XCTAssertEqual(mean, 0, accuracy: 20)            // …but it averages to the centre
        XCTAssertTrue(cents.allSatisfy { abs($0) < 120 }) // and never jumps an octave
    }

    // MARK: decay-glide — starts sharp, settles to the true pitch

    /// Bias-free instantaneous frequency at `start` from the single-bin phase
    /// slope of two hop-spaced frames — locks the fundamental partial itself, so
    /// (unlike raw MPM on a stiff string) it isn't pulled by inharmonicity.
    private func phaseSlopeFreq(_ buf: [Float], start: Int, base: Double, hop: Int = 512, win: Int = 4096) -> Double {
        StrobePhase.refineFrequency(
            current: Array(buf[start..<start + win]),
            previous: Array(buf[start - hop..<start - hop + win]),
            frequency: base, sampleRate: fs, hop: hop)
    }

    func testDecayGlideStartsSharpAndSettles() {
        let settled = 110.0   // A2
        let buf = Synth.decayGlide(settledFrequency: settled, sampleRate: fs, seconds: 2.0,
                                   glideCents: 20, glideTau: 0.6)

        // Early (~t=10 ms): the glide reads clearly sharp.
        let earlyCents = ErrorStats.centsError(estimate: phaseSlopeFreq(buf, start: 512, base: settled), truth: settled)
        XCTAssertGreaterThan(earlyCents, 10)

        // Late (~t=1.7 s): glide gone — within a couple cents of the true settled
        // pitch (the residual is just the +0.26 ¢ stiff-string offset, not bias).
        let lateCents = ErrorStats.centsError(estimate: phaseSlopeFreq(buf, start: Int(1.7 * fs), base: settled), truth: settled)
        XCTAssertLessThan(abs(lateCents), 3)
        XCTAssertGreaterThan(earlyCents, lateCents + 8)   // it actually settled

        // And it never reads as a different octave through the glide.
        let mpm = PitchDetector.detect(Array(buf[Int(1.7 * fs)..<Int(1.7 * fs) + 4096]),
                                       sampleRate: fs, range: PitchPipeline.searchRange, method: .mpm)
        XCTAssertEqual(mpm?.frequency ?? 0, settled, accuracy: settled * 0.2)
    }
}
