import Testing
@testable import TunerEngine

@Suite struct SpectralAnalyzerTests {
    let fs = 48_000.0

    private func cents(_ e: Double, _ t: Double) -> Double { ErrorStats.centsError(estimate: e, truth: t) }

    @Test func dftPeaksAtToneFrequency() {
        let f = 440.0
        let frame = Synth.pure(frequency: f, sampleRate: fs, seconds: 0.1)
        let onPeak  = SpectralAnalyzer.magnitude(frame, frequency: f,       sampleRate: fs)
        let offPeak = SpectralAnalyzer.magnitude(frame, frequency: f * 1.5, sampleRate: fs)
        #expect(onPeak > 50 * offPeak)
    }

    @Test func candanRefineIsSubCentOnCleanTones() {
        for f in [196.0, 329.63, 440.0, 659.26] {
            for c in [-30.0, 7.0, 41.0] {
                let truth = Synth.detune(f, cents: c)
                let frame = Synth.pure(frequency: truth, sampleRate: fs, seconds: 4096.0 / fs)
                let seed  = Synth.detune(truth, cents: 3)
                let r = SpectralAnalyzer.refineFundamental(frame, near: seed, sampleRate: fs, interp: .candan)
                #expect(abs(cents(r, truth)) < 0.05, "candan f=\(f) \(c)¢")
            }
        }
    }

    @Test func logParabolicHannRefineImprovesWithBin() {
        let mid  = Synth.detune(196.0,  cents: 23)
        let high = Synth.detune(659.26, cents: 23)
        let rMid = SpectralAnalyzer.refineFundamental(
            Synth.pure(frequency: mid,  sampleRate: fs, seconds: 4096.0 / fs),
            near: Synth.detune(mid,  cents: 4), sampleRate: fs, interp: .logParabolicHann)
        let rHigh = SpectralAnalyzer.refineFundamental(
            Synth.pure(frequency: high, sampleRate: fs, seconds: 4096.0 / fs),
            near: Synth.detune(high, cents: 4), sampleRate: fs, interp: .logParabolicHann)
        #expect(abs(cents(rMid,  mid))  < 0.5)
        #expect(abs(cents(rHigh, high)) < 0.15)
    }

    @Test func refineNeverLeavesTheClampBand() {
        let frame = Synth.pure(frequency: 330.0, sampleRate: fs, seconds: 4096.0 / fs)
        let r = SpectralAnalyzer.refineFundamental(frame, near: 660.0, sampleRate: fs, interp: .candan)
        #expect(r > 600, "must not correct the octave — that's MPM's job")
        #expect(abs(cents(r, 660.0)) < 50)                         // stayed inside ±50¢
    }

    @Test func refineDefersOnSilenceAndMissingFundamental() {
        #expect(SpectralAnalyzer.refineFundamental([Float](repeating: 0, count: 4096),
                                                   near: 200, sampleRate: fs, interp: .candan) == 200)
        let missing = Synth.inharmonicString(fundamental: 110, sampleRate: fs, seconds: 4096.0 / fs, fundamentalLevel: 0)
        let r = SpectralAnalyzer.refineFundamental(missing, near: 110, sampleRate: fs, interp: .candan)
        #expect(abs(cents(r, 110.0)) < 50)
    }
}
