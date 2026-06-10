import Foundation
import Testing
@testable import TunerEngine

// Tests for the Plan 06 P2 harmonic comb estimator and its (f0, B) regression.
// All tests are headless / deterministic — no audio hardware, no timing.

@Suite("Inharmonicity regression") struct InharmonicityTests {

    @Test("exact recovery on perfect synthetic partials")
    func exactRecovery() throws {
        let f0True = 82.41, BTrue = 3e-4
        let ms = (1...8).map { n in
            Inharmonicity.Measurement(
                n: n,
                frequency: Inharmonicity.partialFrequency(n: n, f0: f0True, B: BTrue),
                weight: Double(n * n)
            )
        }
        let fit = try #require(Inharmonicity.fit(ms))
        #expect(abs(fit.f0 - f0True) < 1e-6, "f0 recovered: \(fit.f0) vs \(f0True)")
        #expect(abs(fit.B  - BTrue)  < 1e-8, "B recovered: \(fit.B) vs \(BTrue)")
        #expect(fit.residualRMS < 1e-8)
        #expect(fit.partialCount == 8)
    }

    @Test("returns nil with fewer than 2 measurements")
    func tooFewMeasurements() {
        let m = Inharmonicity.Measurement(n: 1, frequency: 82.41, weight: 1)
        #expect(Inharmonicity.fit([m]) == nil)
        #expect(Inharmonicity.fit([]) == nil)
    }

    @Test("B is clamped to zero for harmonic (B=0) input")
    func zeroB() throws {
        let f0 = 110.0
        let ms = (1...6).map { n in
            Inharmonicity.Measurement(n: n, frequency: Double(n) * f0, weight: Double(n * n))
        }
        let fit = try #require(Inharmonicity.fit(ms))
        #expect(abs(fit.f0 - f0) < 1e-6)
        #expect(fit.B >= 0)
        #expect(fit.B < 1e-8)
    }

    @Test("partialFrequency helper matches stiff-string law")
    func partialFrequencyHelper() {
        let f0 = 30.87, B = 3e-4
        for n in 1...10 {
            let expected = Double(n) * f0 * (1 + B * Double(n * n)).squareRoot()
            let got = Inharmonicity.partialFrequency(n: n, f0: f0, B: B)
            #expect(abs(got - expected) < 1e-12)
        }
    }
}

@Suite("HarmonicEstimator") struct HarmonicEstimatorTests {

    let sampleRate: Double = 48_000
    // Guitar low E2 — right at the spectralRefineMinHz boundary (82 Hz < 120 Hz).
    let f0E2: Double = 82.41
    // 5-string bass low B — the hardest case (~31 Hz).
    let f0B0: Double = 30.87
    // Benchmark standard inharmonicity coefficient.
    let B: Double = 3e-4

    // Helper: synthesize an inharmonic frame at steady-state.
    func steadyFrame(f0: Double, B: Double, fundamentalLevel: Double = 1) -> [Float] {
        let seconds = 0.15
        let signal = Synth.inharmonicString(
            fundamental: f0, sampleRate: sampleRate, seconds: seconds,
            inharmonicity: B, fundamentalLevel: fundamentalLevel
        )
        // Grab a 4096-sample window from mid-signal (well past any transients).
        let start = Int(0.05 * sampleRate)
        return Array(signal[start ..< (start + 4096)])
    }

    @Test("E2 inharmonic — f0 recovery within 1 ¢")
    func e2F0Recovery() throws {
        let frame = steadyFrame(f0: f0E2, B: B)
        let result = try #require(HarmonicEstimator.refine(frame, near: f0E2, sampleRate: sampleRate))
        let errCents = 1200 * log2(result.frequency / f0E2)
        #expect(abs(errCents) < 1.0, "E2 f0 error \(String(format: "%.2f", errCents))¢ > 1¢")
    }

    @Test("B0 inharmonic — f0 recovery within 2 ¢")
    func b0F0Recovery() throws {
        let frame = steadyFrame(f0: f0B0, B: B)
        let result = try #require(HarmonicEstimator.refine(frame, near: f0B0, sampleRate: sampleRate))
        let errCents = 1200 * log2(result.frequency / f0B0)
        #expect(abs(errCents) < 2.0, "B0 f0 error \(String(format: "%.2f", errCents))¢ > 2¢")
    }

    @Test("missing fundamental — still recovers f0 from upper partials")
    func missingFundamental() throws {
        let frame = steadyFrame(f0: f0E2, B: B, fundamentalLevel: 0)
        let result = try #require(
            HarmonicEstimator.refine(frame, near: f0E2, sampleRate: sampleRate),
            "Expected result even without fundamental"
        )
        let errCents = 1200 * log2(result.frequency / f0E2)
        #expect(abs(errCents) < 2.0, "Missing-fund E2 error \(String(format: "%.2f", errCents))¢ > 2¢")
    }

    @Test("weak fundamental (0.15×) — still recovers f0")
    func weakFundamental() throws {
        let frame = steadyFrame(f0: f0E2, B: B, fundamentalLevel: 0.15)
        let result = try #require(
            HarmonicEstimator.refine(frame, near: f0E2, sampleRate: sampleRate)
        )
        let errCents = 1200 * log2(result.frequency / f0E2)
        #expect(abs(errCents) < 2.0, "Weak-fund E2 error \(String(format: "%.2f", errCents))¢ > 2¢")
    }

    @Test("inharmonicity coefficient B recovered within 50 %")
    func bRecovery() throws {
        let frame = steadyFrame(f0: f0E2, B: B)
        let result = try #require(HarmonicEstimator.refine(frame, near: f0E2, sampleRate: sampleRate))
        let relErr = abs(result.inharmonicityB - B) / B
        #expect(relErr < 0.5, "B relative error \(String(format: "%.0f", relErr * 100))% > 50%")
    }

    @Test("octave safety — result never shifts f0 by more than 50 ¢")
    func octaveSafety() {
        // Pure tone: no harmonics, so the fit may fail (nil) or return something close.
        // Use 0.2 s so the 4096-sample window at t=50 ms fits comfortably.
        let signal = Synth.pure(frequency: f0E2, sampleRate: sampleRate, seconds: 0.2)
        let start = Int(0.05 * sampleRate)
        let frame = Array(signal[start ..< (start + 4096)])
        if let result = HarmonicEstimator.refine(frame, near: f0E2, sampleRate: sampleRate) {
            let centsShift = abs(1200 * log2(result.frequency / f0E2))
            #expect(centsShift <= HarmonicEstimator.maxF0ShiftCents)
        }
        // nil is also acceptable — not enough partials to form a fit.
    }

    @Test("partialCount reflects how many partials contributed")
    func partialCount() throws {
        let frame = steadyFrame(f0: f0E2, B: B)
        let result = try #require(HarmonicEstimator.refine(frame, near: f0E2, sampleRate: sampleRate))
        #expect(result.partialCount >= HarmonicEstimator.minPartials)
    }
}
