import Testing
import Foundation
@testable import TunerEngine

@Suite struct BenchmarkTests {
    let fs = 48_000.0

    @Test func errorStats() {
        let s = ErrorStats.from([-2, -1, 0, 1, 2])
        #expect(s.count == 5)
        #expect(abs(s.mean - 0) < 1e-12)
        #expect(abs(s.meanAbs - 1.2) < 1e-12)
        #expect(abs(s.sigma - 2.0.squareRoot()) < 1e-12)
        #expect(abs(s.maxAbs - 2) < 1e-12)
    }

    @Test func centsErrorHelper() {
        #expect(abs(ErrorStats.centsError(estimate: 880, truth: 440) - 1200) < 1e-9)
        #expect(abs(ErrorStats.centsError(estimate: 440, truth: 440) - 0) < 1e-9)
    }

    @Test func seededRNGDeterministic() {
        var a = SeededRNG(seed: 7), b = SeededRNG(seed: 7)
        for _ in 0..<100 { #expect(a.next() == b.next()) }
    }

    @Test func noiseHitsTargetSNR() {
        var rng = SeededRNG(seed: 1)
        let sig = Synth.pure(frequency: 200, sampleRate: fs, seconds: 0.5)
        let noisy = Synth.addNoise(to: sig, snrDB: 20, rng: &rng)
        let sigP = sig.reduce(0.0) { $0 + Double($1) * Double($1) } / Double(sig.count)
        let noiseP = zip(sig, noisy).reduce(0.0) { $0 + pow(Double($1.1 - $1.0), 2) } / Double(sig.count)
        let measuredSNR = 10 * log10(sigP / noiseP)
        #expect(abs(measuredSNR - 20) < 1.5)
    }

    @Test func caseRunnerScoresCleanTone() {
        let sig = Synth.harmonic(fundamental: 196, sampleRate: fs, seconds: 2.0)
        let r = CaseRunner.run(signal: sig, sampleRate: fs, trueFrequency: 196,
                               category: "harmonic", centsTarget: 0, snrDB: .infinity, method: .mpm)
        #expect(!r.octaveError)
        #expect(r.stats.meanAbs < 3.0)
        #expect(r.timeToLockMS != nil)
        #expect((r.timeToLockMS ?? 999) < 350)
    }

    @Test func allMethodsScoreAccurately() {
        // The "let the benchmark decide" smoke test — each method stays octave-safe
        // and accurate on a representative tone. (The full MPM/YIN/hybrid matrix
        // runs in the release `Benchmark` CI step; kept light here for debug speed.)
        let sig = Synth.inharmonicString(fundamental: 146.83, sampleRate: fs, seconds: 0.7)  // D3
        for method in DetectionMethod.allCases {
            let r = CaseRunner.run(signal: sig, sampleRate: fs, trueFrequency: 146.83,
                                   category: "inharmonic", centsTarget: 0, snrDB: .infinity, method: method)
            #expect(!r.octaveError, "\(method) octave-safe")
            #expect(r.stats.meanAbs < 1.0, "\(method) accuracy")
        }
    }

    @Test func caseRunnerPolicyParamRoutesToPipeline() {
        let fs = 48_000.0
        let sig = Synth.inharmonicString(fundamental: 110, sampleRate: fs, seconds: 1.2)

        // Default policy == .fullRange (backward-compatible, zero-delta).
        let dflt = CaseRunner.run(signal: sig, sampleRate: fs, trueFrequency: 110,
                                  category: "t", centsTarget: 0, snrDB: .infinity, method: .mpm)
        let full = CaseRunner.run(signal: sig, sampleRate: fs, trueFrequency: 110,
                                  category: "t", centsTarget: 0, snrDB: .infinity, method: .mpm,
                                  policy: .fullRange)
        #expect(dflt.readings == full.readings)
        #expect(dflt.stats == full.stats)

        // A policy whose searchRange excludes 110 Hz must change the result —
        // proves the parameter actually reaches the pipeline.
        let narrow = DetectionPolicy(searchRange: 200...400, bands: DetectionPolicy.fullRange.bands,
                                     acquire: DetectionPolicy.fullRange.acquire,
                                     smoothingAlpha: 0.35, smoothingMedianCount: 5, emitFloor: 0.5)
        let clamped = CaseRunner.run(signal: sig, sampleRate: fs, trueFrequency: 110,
                                     category: "t", centsTarget: 0, snrDB: .infinity, method: .mpm,
                                     policy: narrow)
        #expect(clamped.stats.meanAbs != full.stats.meanAbs, "narrow searchRange must change the estimate")
    }

    @Test func benchmarkExposesBassPolicySummary() {
        // Exercise the bass-policy wiring on the 10 bass cases directly (~seconds),
        // not the full BenchmarkSuite.run() matrix (~11 min). run() calls this exact
        // helper, so this proves the same path it ships.
        let result = BenchmarkSuite.bassPolicyPass(method: .mpm, sampleRate: fs,
                                                    a4: Pitch.standardA4,
                                                    lockWindowStart: BenchmarkSuite.lockWindowStart)
        #expect(!result.isEmpty, "bass-policy pass must run cases")
        let categories = Set(result.map { $0.category })
        #expect(categories.contains("bass-clean"), "bass-clean category present")
        #expect(categories.contains("bass-weak-fund"), "bass-weak-fund category present")
        for r in result {
            #expect(r.lockRetention >= 0)
            #expect(r.lockRetention <= 1)
        }

        // Feed the small result through the Summary aggregation to prove the wiring
        // cheaply (bassPolicyCases populated, retention in range).
        let summary = BenchmarkSuite.summarize(clean: [], stress: [], bassPolicy: result, method: .mpm)
        #expect(summary.bassPolicyCases > 0, "Summary aggregates bass-policy cases")
        #expect(summary.bassLockRetention >= 0)
        #expect(summary.bassLockRetention <= 1)
    }

    @Test func lockTrajectoryComputesRetentionAndDrops() {
        func r(_ t: TimeInterval, _ locked: Bool) -> PitchReading {
            PitchReading(frequency: 110, note: Note(midi: 45), cents: 0, confidence: 0.9,
                         phase: 0, timestamp: t, inharmonicityB: nil,
                         precisionCents: locked ? 0.1 : nil, isLockIntegrated: locked)
        }
        // Pre-window frames (t < 1.0) are ignored. In-window: L, L, unlocked, L → one drop,
        // 3/4 locked.
        let readings = [r(0.5, true), r(1.0, true), r(1.2, true), r(1.4, false), r(1.6, true)]
        let (retention, drops) = CaseRunner.lockTrajectory(readings, windowStart: 1.0)
        #expect(abs(retention - 0.75) < 1e-9)
        #expect(drops == 1)

        // Never locks in window → 0 retention, 0 drops.
        let none = [r(1.0, false), r(1.2, false)]
        let (ret2, drops2) = CaseRunner.lockTrajectory(none, windowStart: 1.0)
        #expect(ret2 == 0)
        #expect(drops2 == 0)
    }
}
