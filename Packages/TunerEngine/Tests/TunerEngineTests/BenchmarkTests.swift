import XCTest
@testable import TunerEngine

final class BenchmarkTests: XCTestCase {
    let fs = 48_000.0

    func testErrorStats() {
        let s = ErrorStats.from([-2, -1, 0, 1, 2])
        XCTAssertEqual(s.count, 5)
        XCTAssertEqual(s.mean, 0, accuracy: 1e-12)
        XCTAssertEqual(s.meanAbs, 1.2, accuracy: 1e-12)
        XCTAssertEqual(s.sigma, 2.0.squareRoot(), accuracy: 1e-12)
        XCTAssertEqual(s.maxAbs, 2, accuracy: 1e-12)
    }

    func testCentsErrorHelper() {
        XCTAssertEqual(ErrorStats.centsError(estimate: 880, truth: 440), 1200, accuracy: 1e-9)
        XCTAssertEqual(ErrorStats.centsError(estimate: 440, truth: 440), 0, accuracy: 1e-9)
    }

    func testSeededRNGDeterministic() {
        var a = SeededRNG(seed: 7), b = SeededRNG(seed: 7)
        for _ in 0..<100 { XCTAssertEqual(a.next(), b.next()) }
    }

    func testNoiseHitsTargetSNR() {
        var rng = SeededRNG(seed: 1)
        let sig = Synth.pure(frequency: 200, sampleRate: fs, seconds: 0.5)
        let noisy = Synth.addNoise(to: sig, snrDB: 20, rng: &rng)
        let sigP = sig.reduce(0.0) { $0 + Double($1) * Double($1) } / Double(sig.count)
        let noiseP = zip(sig, noisy).reduce(0.0) { $0 + pow(Double($1.1 - $1.0), 2) } / Double(sig.count)
        let measuredSNR = 10 * log10(sigP / noiseP)
        XCTAssertEqual(measuredSNR, 20, accuracy: 1.5)
    }

    func testCaseRunnerScoresCleanTone() {
        let sig = Synth.harmonic(fundamental: 196, sampleRate: fs, seconds: 0.8)
        let r = CaseRunner.run(signal: sig, sampleRate: fs, trueFrequency: 196,
                               category: "harmonic", centsTarget: 0, snrDB: .infinity, method: .mpm)
        XCTAssertFalse(r.octaveError)
        XCTAssertLessThan(r.stats.meanAbs, 3.0)
        XCTAssertNotNil(r.timeToLockMS)
        XCTAssertLessThan(r.timeToLockMS ?? 999, 350)
    }

    func testAllMethodsScoreAccurately() {
        // The "let the benchmark decide" smoke test — each method stays octave-safe
        // and accurate on a representative tone. (The full MPM/YIN/hybrid matrix
        // runs in the release `Benchmark` CI step; kept light here for debug speed.)
        let sig = Synth.inharmonicString(fundamental: 146.83, sampleRate: fs, seconds: 0.7)  // D3
        for method in DetectionMethod.allCases {
            let r = CaseRunner.run(signal: sig, sampleRate: fs, trueFrequency: 146.83,
                                   category: "inharmonic", centsTarget: 0, snrDB: .infinity, method: method)
            XCTAssertFalse(r.octaveError, "\(method) octave-safe")
            XCTAssertLessThan(r.stats.meanAbs, 12, "\(method) accuracy")
        }
    }
}
