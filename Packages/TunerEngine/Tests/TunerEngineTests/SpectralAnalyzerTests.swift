import XCTest
@testable import TunerEngine

final class SpectralAnalyzerTests: XCTestCase {
    let fs = 48_000.0

    private func cents(_ e: Double, _ t: Double) -> Double { ErrorStats.centsError(estimate: e, truth: t) }

    func testDFTPeaksAtToneFrequency() {
        let f = 440.0
        let frame = Synth.pure(frequency: f, sampleRate: fs, seconds: 0.1)
        let onPeak = SpectralAnalyzer.magnitude(frame, frequency: f, sampleRate: fs)
        let offPeak = SpectralAnalyzer.magnitude(frame, frequency: f * 1.5, sampleRate: fs)
        XCTAssertGreaterThan(onPeak, 50 * offPeak)
    }

    func testCandanRefineIsSubCentOnCleanTones() {
        // Mid/high, detuned: the refine should land within a few hundredths of a cent.
        for f in [196.0, 329.63, 440.0, 659.26] {
            for cents in [-30.0, 7.0, 41.0] {
                let truth = Synth.detune(f, cents: cents)
                let frame = Synth.pure(frequency: truth, sampleRate: fs, seconds: 4096.0 / fs)
                // Seed with f0 a few cents off (as MPM would be), same bin.
                let seed = Synth.detune(truth, cents: 3)
                let r = SpectralAnalyzer.refineFundamental(frame, near: seed, sampleRate: fs, interp: .candan)
                XCTAssertLessThan(abs(self.cents(r, truth)), 0.05, "candan f=\(f) \(cents)¢")
            }
        }
    }

    func testLogParabolicHannRefineImprovesWithBin() {
        // The Hann log-parabolic fallback degrades at low bins (image leakage) but
        // is robust; it's well under a cent across the core and tightens up high.
        let mid = Synth.detune(196.0, cents: 23)
        let high = Synth.detune(659.26, cents: 23)
        let rMid = SpectralAnalyzer.refineFundamental(
            Synth.pure(frequency: mid, sampleRate: fs, seconds: 4096.0 / fs),
            near: Synth.detune(mid, cents: 4), sampleRate: fs, interp: .logParabolicHann)
        let rHigh = SpectralAnalyzer.refineFundamental(
            Synth.pure(frequency: high, sampleRate: fs, seconds: 4096.0 / fs),
            near: Synth.detune(high, cents: 4), sampleRate: fs, interp: .logParabolicHann)
        XCTAssertLessThan(abs(cents(rMid, mid)), 0.5)
        XCTAssertLessThan(abs(cents(rHigh, high)), 0.15)
    }

    // MARK: octave safety / deferral — MPM stays the authority

    func testRefineNeverLeavesTheClampBand() {
        let frame = Synth.pure(frequency: 330.0, sampleRate: fs, seconds: 4096.0 / fs)
        // A (hypothetical) octave-off seed: refine must NOT secretly jump to 330.
        let r = SpectralAnalyzer.refineFundamental(frame, near: 660.0, sampleRate: fs, interp: .candan)
        XCTAssertGreaterThan(r, 600, "must not correct the octave — that's MPM's job")
        XCTAssertEqual(cents(r, 660.0), 0, accuracy: 50)   // stayed inside ±50¢
    }

    func testRefineDefersOnSilenceAndMissingFundamental() {
        // Silence → unchanged.
        XCTAssertEqual(SpectralAnalyzer.refineFundamental([Float](repeating: 0, count: 4096),
                                                          near: 200, sampleRate: fs, interp: .candan), 200)
        // Missing fundamental → stays within ±50¢ of the seed (no spurious lock).
        let missing = Synth.inharmonicString(fundamental: 110, sampleRate: fs, seconds: 4096.0 / fs, fundamentalLevel: 0)
        let r = SpectralAnalyzer.refineFundamental(missing, near: 110, sampleRate: fs, interp: .candan)
        XCTAssertEqual(cents(r, 110.0), 0, accuracy: 50)
    }
}
