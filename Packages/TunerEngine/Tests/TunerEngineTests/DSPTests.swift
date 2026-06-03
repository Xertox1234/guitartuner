import XCTest
@testable import TunerEngine

final class DSPTests: XCTestCase {

    // MARK: Preprocessing

    func testDCBlockerRemovesBias() {
        var pre = Preprocessor(sampleRate: 48_000)
        var last: Float = 0
        for _ in 0..<16_000 { last = pre.process(1.0) }   // constant DC, ~0.33 s
        XCTAssertEqual(last, 0, accuracy: 0.02)            // settles to ~0
    }

    func testHighPassPreservesMusicalBand() {
        var pre = Preprocessor(sampleRate: 48_000)
        let sig = Synth.pure(frequency: 200, sampleRate: 48_000, seconds: 0.2)
        var out = [Float]()
        for s in sig { out.append(pre.process(s)) }
        // Compare RMS over the settled tail.
        let inRMS = rms(Array(sig.suffix(4000)))
        let outRMS = rms(Array(out.suffix(4000)))
        XCTAssertEqual(outRMS / inRMS, 1.0, accuracy: 0.15)   // ~unity at 200 Hz
    }

    func testHighPassAttenuatesRumble() {
        var pre = Preprocessor(sampleRate: 48_000)
        let sig = Synth.pure(frequency: 8, sampleRate: 48_000, seconds: 0.5)
        var out = [Float]()
        for s in sig { out.append(pre.process(s)) }
        let inRMS = rms(Array(sig.suffix(8000)))
        let outRMS = rms(Array(out.suffix(8000)))
        XCTAssertLessThan(outRMS / inRMS, 0.2)                // 8 Hz strongly cut
    }

    // MARK: Correlation / NSDF identities

    func testNSDFAtZeroLagIsOne() {
        let frame = Synth.pure(frequency: 480, sampleRate: 48_000, seconds: 0.05)
        let corr = Correlation.compute(frame, maxLag: 500)
        XCTAssertEqual(corr.nsdf(0), 1, accuracy: 1e-6)
    }

    func testAutocorrelationUnitsMatchEnergy() {
        let frame = Synth.pure(frequency: 480, sampleRate: 48_000, seconds: 0.05)
        let corr = Correlation.compute(frame, maxLag: 500)
        // r[0] == Σ x² == prefixEnergy[N].
        XCTAssertEqual(corr.r[0], corr.prefixEnergy[corr.count], accuracy: corr.r[0] * 1e-4 + 1e-6)
    }

    func testNSDFPeaksAtPeriod() {
        // Period of exactly 100 samples (fs/100).
        let frame = Synth.pure(frequency: 480, sampleRate: 48_000, seconds: 0.04)  // 480 Hz → 100-sample period
        let corr = Correlation.compute(frame, maxLag: 250)
        XCTAssertGreaterThan(corr.nsdf(100), 0.95)
        // Half-period should be clearly lower (octave discrimination).
        XCTAssertLessThan(corr.nsdf(50), corr.nsdf(100))
    }

    // MARK: Parabolic interpolation

    func testParabolicVertex() {
        // y = 5 − (x − 0.3)² sampled at −1, 0, 1.
        let f = { (x: Double) in 5 - (x - 0.3) * (x - 0.3) }
        let (offset, value) = parabolicVertex(f(-1), f(0), f(1))
        XCTAssertEqual(offset, 0.3, accuracy: 1e-9)
        XCTAssertEqual(value, 5, accuracy: 1e-9)
    }

    func testParabolicVertexFlat() {
        let (offset, value) = parabolicVertex(1, 1, 1)
        XCTAssertEqual(offset, 0, accuracy: 1e-12)
        XCTAssertEqual(value, 1, accuracy: 1e-12)
    }

    private func rms(_ xs: [Float]) -> Double {
        guard !xs.isEmpty else { return 0 }
        return (xs.reduce(0.0) { $0 + Double($1) * Double($1) } / Double(xs.count)).squareRoot()
    }
}
