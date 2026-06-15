import Testing
import Foundation
@testable import TunerEngine

@Suite("ClockCalibration")
struct ClockCalibrationTests {

    // A fast crystal running 44 ppm fast (real measured value, cited in Plan 06 §7.1).
    static let fastPPM: Double = 44.0
    static let nominal: Double = 48_000.0

    // Simulate a device whose crystal runs at `ppmError` ppm from nominal.
    // Uses one large sample batch to avoid per-batch integer rounding.
    private func feed(
        cal: ClockCalibration,
        ppmError: Double,
        durationSeconds: Double
    ) {
        let actualRate = ClockCalibrationTests.nominal * (1.0 + ppmError / 1_000_000)
        cal.startMeasurement(wallTime: 0.0)
        // One large batch: the crystal delivers this many samples over `duration`.
        let samples = Int(actualRate * durationSeconds)
        cal.observe(sampleCount: samples, wallTime: durationSeconds)
    }

    @Test("not converged before minCalibrationDuration")
    func notConvergedEarly() {
        let cal = ClockCalibration(nominalRate: Self.nominal)
        feed(cal: cal, ppmError: Self.fastPPM, durationSeconds: 10.0)
        #expect(!cal.isConverged)
        #expect(cal.correctionFactor == 1.0)   // no correction before convergence
    }

    @Test("converges and measures positive ppm correctly")
    func fastCrystalPositivePPM() {
        let cal = ClockCalibration(nominalRate: Self.nominal)
        feed(cal: cal, ppmError: Self.fastPPM, durationSeconds: 60.0)
        #expect(cal.isConverged)
        // Int truncation loses <1 sample per 1-minute batch → <0.02 ppm error.
        #expect(abs(cal.measuredPPM - Self.fastPPM) < 2.0)
        #expect(cal.correctionFactor > 1.0)
    }

    @Test("converges and measures negative ppm correctly")
    func slowCrystalNegativePPM() {
        let cal = ClockCalibration(nominalRate: Self.nominal)
        feed(cal: cal, ppmError: -30.0, durationSeconds: 60.0)
        #expect(cal.isConverged)
        #expect(abs(cal.measuredPPM - (-30.0)) < 2.0)
        #expect(cal.correctionFactor < 1.0)
    }

    @Test("correction factor removes clock error to within calibrated spec")
    func correctionFactorRemovesError() {
        let cal = ClockCalibration(nominalRate: Self.nominal)
        feed(cal: cal, ppmError: Self.fastPPM, durationSeconds: 60.0)
        #expect(cal.isConverged)
        // A fast crystal under-reports frequency (more samples per real second means
        // a shorter apparent period). The true frequency is:
        //   trueHz = measuredHz * correctionFactor
        // After applying the correction, absolute accuracy = uncertaintyPPM/577.8 ¢.
        let absoluteAccuracy = cal.absoluteAccuracyCents
        #expect(absoluteAccuracy < 0.02)   // calibrated-mode spec
    }

    @Test("absoluteAccuracyCents before convergence is within uncalibrated spec")
    func absoluteAccuracyUnconverged() {
        let cal = ClockCalibration(nominalRate: Self.nominal)
        // No measurement started — worst-case uncalibrated claim ≤0.17 ¢ (100 ppm).
        #expect(cal.absoluteAccuracyCents < 0.20)
    }

    @Test("reset clears accumulated data")
    func resetClearsState() {
        let cal = ClockCalibration(nominalRate: Self.nominal)
        feed(cal: cal, ppmError: Self.fastPPM, durationSeconds: 60.0)
        #expect(cal.isConverged)
        cal.reset()
        #expect(!cal.isConverged)
        #expect(cal.measuredPPM == 0.0)
        #expect(cal.correctionFactor == 1.0)
    }

    @Test("zero ppm crystal gives correction factor ≈ 1")
    func zeroPPMCrystal() {
        let cal = ClockCalibration(nominalRate: Self.nominal)
        feed(cal: cal, ppmError: 0.0, durationSeconds: 60.0)
        #expect(cal.isConverged)
        #expect(abs(cal.measuredPPM) < 1.0)
        #expect(abs(cal.correctionFactor - 1.0) < 1e-5)
    }

    @Test("observe before startMeasurement is a no-op")
    func observeBeforeStart() {
        let cal = ClockCalibration(nominalRate: Self.nominal)
        cal.observe(sampleCount: 48000, wallTime: 1.0)
        #expect(!cal.isConverged)
        #expect(cal.measuredPPM == 0.0)
    }
}
