import XCTest
@testable import TunerEngine

/// Pins the four Plan 06 §16 diagnosis probes so the *diagnosis* — not just the
/// engine — is a CI regression. The numbers here are the ones the plan quotes in
/// §2–§3; if any drifts, either the physics argument or the port broke.
final class DiagnosisProbeTests: XCTestCase {

    // MARK: Probe A — bias is the enemy, integration is the cure (Plan §2.1, §2.4)

    func testProbeA_singleFundamentalIsBiased_integrationIsNot() {
        let clean = Diagnosis.probeA(snrDB: .infinity)
        // ACF + parabolic on one frame reads ~+10.6 ¢ sharp — a *bias*, not noise.
        XCTAssertEqual(clean.acfFundamentalCents, 10.644, accuracy: 0.05)
        // Long phase-slope integration on the fundamental alone: ~−0.044 ¢.
        XCTAssertEqual(clean.phaseSlopeFundamentalCents, -0.0437, accuracy: 0.01)
        // Multi-partial k²-weighted fusion: ~+0.003 ¢ — three orders better.
        XCTAssertEqual(clean.phaseSlope10PartialCents, 0.0028, accuracy: 0.005)

        // The thesis, asserted directly: the single-frame bias dwarfs the
        // integrated error by >100×, and no averaging removes a bias.
        XCTAssertGreaterThan(abs(clean.acfFundamentalCents), 5.0)
        XCTAssertLessThan(abs(clean.phaseSlope10PartialCents), 0.05)
    }

    func testProbeA_robustInNoise() {
        let n40 = Diagnosis.probeA(snrDB: 40, seed: 0xBEEF)
        XCTAssertEqual(n40.acfFundamentalCents, 10.624, accuracy: 0.05)
        XCTAssertEqual(n40.phaseSlope10PartialCents, 0.0027, accuracy: 0.005)
    }

    // MARK: Probe B — parabolic interpolation bias (Plan §2.2)

    func testProbeB_parabolicBias() {
        let b = Diagnosis.probeB()
        XCTAssertEqual(b.parabolicLinearCents, 0.4570, accuracy: 0.005)   // 5.3 % of a bin
        XCTAssertEqual(b.parabolicLogCents, 0.1385, accuracy: 0.005)
        // Log-magnitude parabola is materially better than linear.
        XCTAssertLessThan(b.parabolicLogCents, b.parabolicLinearCents)
    }

    // MARK: Probe C — CRLB floor + clock floor (Plan §2.3, §3)

    func testProbeC_crlbAndClockFloor() {
        let c = Diagnosis.probeC()
        XCTAssertEqual(c.crlbSingleCents, 0.0212, accuracy: 0.0003)
        XCTAssertEqual(c.crlbHarmonic10Cents, 0.001081, accuracy: 2e-5)
        // Harmonic floor is ~√385 ≈ 19.6× below the single-tone floor.
        XCTAssertEqual(c.crlbSingleCents / c.crlbHarmonic10Cents, 385.0.squareRoot(), accuracy: 0.2)
        // Clock (ppm) floor — the absolute-accuracy limiter.
        XCTAssertEqual(c.ppm20, 0.0346, accuracy: 0.001)
        XCTAssertEqual(c.ppm44, 0.0762, accuracy: 0.001)
        XCTAssertEqual(c.ppm100, 0.1731, accuracy: 0.001)
        XCTAssertEqual(c.ppmPerCent, 577.8, accuracy: 0.5)
    }

    // MARK: Probe D — joint (f0, B) recovery is exact on the model (Plan §2.5)

    func testProbeD_jointF0BRecovery() {
        let d = Diagnosis.probeD()
        XCTAssertEqual(d.recoveredF0, 82.41, accuracy: 1e-4)
        XCTAssertEqual(d.recoveredF0Cents, 0, accuracy: 1e-6)    // exact on the synth model
        XCTAssertEqual(d.recoveredB, 3e-4, accuracy: 1e-9)
        XCTAssertEqual(d.sharpnessN8, 16.62, accuracy: 0.05)
        XCTAssertEqual(d.sharpnessN10, 25.97, accuracy: 0.05)    // ≈ benchmark worst case 25.71 ¢
    }

    // MARK: Crlb unit identities (the calculator the column depends on)

    func testCrlbHarmonicWeight() {
        // Equal-amplitude partials: Σ k² = 385 (the idealised probe-C convention).
        XCTAssertEqual(Crlb.harmonicWeight(amplitudes: [Double](repeating: 1, count: 10)), 385, accuracy: 1e-9)
        // Realistic ∝1/k partials (fundamental = 1): each term (1/k·k)² = 1 ⇒ weight = P = 10,
        // ~38× smaller than equal-amplitude — the honest reason the harmonic floor sits far
        // closer to the single-tone floor than √385 would suggest.
        let invK = (1...10).map { 1.0 / Double($0) }
        XCTAssertEqual(Crlb.harmonicWeight(amplitudes: invK), 10, accuracy: 1e-9)
        XCTAssertLessThan(Crlb.harmonicWeight(amplitudes: invK), 385)
    }
}
