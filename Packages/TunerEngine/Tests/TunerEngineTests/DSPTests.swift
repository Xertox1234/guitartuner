import Foundation
import Testing
@testable import TunerEngine

@Suite struct DSPTests {

    // MARK: Preprocessing

    @Test func dcBlockerRemovesBias() {
        var pre = Preprocessor(sampleRate: 48_000)
        var last: Float = 0
        for _ in 0..<16_000 { last = pre.process(1.0) }   // constant DC, ~0.33 s
        #expect(abs(last) < 0.02)                           // settles to ~0
    }

    @Test func highPassPreservesMusicalBand() {
        var pre = Preprocessor(sampleRate: 48_000)
        let sig = Synth.pure(frequency: 200, sampleRate: 48_000, seconds: 0.2)
        var out = [Float]()
        for s in sig { out.append(pre.process(s)) }
        let inRMS  = rms(Array(sig.suffix(4000)))
        let outRMS = rms(Array(out.suffix(4000)))
        #expect(abs(outRMS / inRMS - 1.0) < 0.15)          // ~unity at 200 Hz
    }

    @Test func highPassAttenuatesRumble() {
        var pre = Preprocessor(sampleRate: 48_000)
        let sig = Synth.pure(frequency: 8, sampleRate: 48_000, seconds: 0.5)
        var out = [Float]()
        for s in sig { out.append(pre.process(s)) }
        let inRMS  = rms(Array(sig.suffix(8000)))
        let outRMS = rms(Array(out.suffix(8000)))
        #expect(outRMS / inRMS < 0.2)                       // 8 Hz strongly cut
    }

    // MARK: Correlation / NSDF identities

    @Test func nsdfAtZeroLagIsOne() {
        let frame = Synth.pure(frequency: 480, sampleRate: 48_000, seconds: 0.05)
        let corr = Correlation.compute(frame, maxLag: 500)
        #expect(abs(corr.nsdf(0) - 1) < 1e-6)
    }

    @Test func autocorrelationUnitsMatchEnergy() {
        let frame = Synth.pure(frequency: 480, sampleRate: 48_000, seconds: 0.05)
        let corr = Correlation.compute(frame, maxLag: 500)
        #expect(abs(corr.r[0] - corr.prefixEnergy[corr.count]) < corr.r[0] * 1e-4 + 1e-6)
    }

    @Test func nsdfPeaksAtPeriod() {
        let frame = Synth.pure(frequency: 480, sampleRate: 48_000, seconds: 0.04)
        let corr = Correlation.compute(frame, maxLag: 250)
        #expect(corr.nsdf(100) > 0.95)
        #expect(corr.nsdf(50) < corr.nsdf(100))
    }

    // MARK: Parabolic interpolation

    @Test func parabolicVertexIsCorrect() {
        // y = 5 − (x − 0.3)² sampled at −1, 0, 1.
        let f = { (x: Double) in 5 - (x - 0.3) * (x - 0.3) }
        let (offset, value) = parabolicVertex(f(-1), f(0), f(1))
        #expect(abs(offset - 0.3) < 1e-9)
        #expect(abs(value  - 5.0) < 1e-9)
    }

    @Test func parabolicVertexFlatInput() {
        let (offset, value) = parabolicVertex(1, 1, 1)
        #expect(abs(offset) < 1e-12)
        #expect(abs(value - 1) < 1e-12)
    }

    private func rms(_ xs: [Float]) -> Double {
        guard !xs.isEmpty else { return 0 }
        return (xs.reduce(0.0) { $0 + Double($1) * Double($1) } / Double(xs.count)).squareRoot()
    }
}
