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
        let sig = Synth.harmonic(fundamental: 196, sampleRate: fs, seconds: 2.0)
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
            XCTAssertLessThan(r.stats.meanAbs, 1.0, "\(method) accuracy")
        }
    }

    func testCaseRunnerPolicyParamRoutesToPipeline() {
        let fs = 48_000.0
        let sig = Synth.inharmonicString(fundamental: 110, sampleRate: fs, seconds: 1.2)

        // Default policy == .fullRange (backward-compatible, zero-delta).
        let dflt = CaseRunner.run(signal: sig, sampleRate: fs, trueFrequency: 110,
                                  category: "t", centsTarget: 0, snrDB: .infinity, method: .mpm)
        let full = CaseRunner.run(signal: sig, sampleRate: fs, trueFrequency: 110,
                                  category: "t", centsTarget: 0, snrDB: .infinity, method: .mpm,
                                  policy: .fullRange)
        XCTAssertEqual(dflt.readings, full.readings)
        XCTAssertEqual(dflt.stats, full.stats)

        // A policy whose searchRange excludes 110 Hz must change the result —
        // proves the parameter actually reaches the pipeline.
        let narrow = DetectionPolicy(searchRange: 200...400, bands: DetectionPolicy.fullRange.bands,
                                     acquire: DetectionPolicy.fullRange.acquire,
                                     smoothingAlpha: 0.35, smoothingMedianCount: 5, emitFloor: 0.5)
        let clamped = CaseRunner.run(signal: sig, sampleRate: fs, trueFrequency: 110,
                                     category: "t", centsTarget: 0, snrDB: .infinity, method: .mpm,
                                     policy: narrow)
        XCTAssertNotEqual(clamped.stats.meanAbs, full.stats.meanAbs, "narrow searchRange must change the estimate")
    }

    func testLockTrajectoryComputesRetentionAndDrops() {
        func r(_ t: TimeInterval, _ locked: Bool) -> PitchReading {
            PitchReading(frequency: 110, note: Note(midi: 45), cents: 0, confidence: 0.9,
                         phase: 0, timestamp: t, inharmonicityB: nil,
                         precisionCents: locked ? 0.1 : nil, isLockIntegrated: locked)
        }
        // Pre-window frames (t < 1.0) are ignored. In-window: L, L, unlocked, L → one drop,
        // 3/4 locked.
        let readings = [r(0.5, true), r(1.0, true), r(1.2, true), r(1.4, false), r(1.6, true)]
        let (retention, drops) = CaseRunner.lockTrajectory(readings, windowStart: 1.0)
        XCTAssertEqual(retention, 0.75, accuracy: 1e-9)
        XCTAssertEqual(drops, 1)

        // Never locks in window → 0 retention, 0 drops.
        let none = [r(1.0, false), r(1.2, false)]
        let (ret2, drops2) = CaseRunner.lockTrajectory(none, windowStart: 1.0)
        XCTAssertEqual(ret2, 0)
        XCTAssertEqual(drops2, 0)
    }
}
