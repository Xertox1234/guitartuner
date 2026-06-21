import Testing
@testable import TunerEngine

/// Pins the four Plan 06 §16 diagnosis probes so the *diagnosis* — not just the
/// engine — is a CI regression. The numbers here are the ones the plan quotes in
/// §2–§3; if any drifts, either the physics argument or the port broke.
@Suite struct DiagnosisProbeTests {

    // MARK: Probe A — bias is the enemy, integration is the cure (Plan §2.1, §2.4)

    @Test func probeA_singleFundamentalIsBiased_integrationIsNot() {
        let clean = Diagnosis.probeA(snrDB: .infinity)
        // ACF + parabolic on one frame reads ~+10.6 ¢ sharp — a *bias*, not noise.
        #expect(abs(clean.acfFundamentalCents - 10.644) < 0.05)
        // Long phase-slope integration on the fundamental alone: ~−0.044 ¢.
        #expect(abs(clean.phaseSlopeFundamentalCents - (-0.0437)) < 0.01)
        // Multi-partial k²-weighted fusion: ~+0.003 ¢ — three orders better.
        #expect(abs(clean.phaseSlope10PartialCents - 0.0028) < 0.005)

        // The thesis, asserted directly: the single-frame bias dwarfs the
        // integrated error by >100×, and no averaging removes a bias.
        #expect(abs(clean.acfFundamentalCents) > 5.0)
        #expect(abs(clean.phaseSlope10PartialCents) < 0.05)
    }

    @Test func probeA_robustInNoise() {
        let n40 = Diagnosis.probeA(snrDB: 40, seed: 0xBEEF)
        #expect(abs(n40.acfFundamentalCents - 10.624) < 0.05)
        #expect(abs(n40.phaseSlope10PartialCents - 0.0027) < 0.005)
    }

    // MARK: Probe B — parabolic interpolation bias (Plan §2.2)

    @Test func probeB_parabolicBias() {
        let b = Diagnosis.probeB()
        #expect(abs(b.parabolicLinearCents - 0.4570) < 0.005)   // 5.3 % of a bin
        #expect(abs(b.parabolicLogCents - 0.1385) < 0.005)
        // Log-magnitude parabola is materially better than linear.
        #expect(b.parabolicLogCents < b.parabolicLinearCents)
    }

    // MARK: Probe C — CRLB floor + clock floor (Plan §2.3, §3)

    @Test func probeC_crlbAndClockFloor() {
        let c = Diagnosis.probeC()
        #expect(abs(c.crlbSingleCents - 0.0212) < 0.0003)
        #expect(abs(c.crlbHarmonic10Cents - 0.001081) < 2e-5)
        // Harmonic floor is ~√385 ≈ 19.6× below the single-tone floor.
        #expect(abs(c.crlbSingleCents / c.crlbHarmonic10Cents - 385.0.squareRoot()) < 0.2)
        // Clock (ppm) floor — the absolute-accuracy limiter.
        #expect(abs(c.ppm20 - 0.0346) < 0.001)
        #expect(abs(c.ppm44 - 0.0762) < 0.001)
        #expect(abs(c.ppm100 - 0.1731) < 0.001)
        #expect(abs(c.ppmPerCent - 577.8) < 0.5)
    }

    // MARK: Probe D — joint (f0, B) recovery is exact on the model (Plan §2.5)

    @Test func probeD_jointF0BRecovery() {
        let d = Diagnosis.probeD()
        #expect(abs(d.recoveredF0 - 82.41) < 1e-4)
        #expect(abs(d.recoveredF0Cents - 0) < 1e-6)    // exact on the synth model
        #expect(abs(d.recoveredB - 3e-4) < 1e-9)
        #expect(abs(d.sharpnessN8 - 16.62) < 0.05)
        #expect(abs(d.sharpnessN10 - 25.97) < 0.05)    // ≈ benchmark worst case 25.71 ¢
    }

    // MARK: Crlb unit identities (the calculator the column depends on)

    @Test func crlbHarmonicWeight() {
        // Equal-amplitude partials: Σ k² = 385 (the idealised probe-C convention).
        #expect(abs(Crlb.harmonicWeight(amplitudes: [Double](repeating: 1, count: 10)) - 385) < 1e-9)
        // Realistic ∝1/k partials (fundamental = 1): each term (1/k·k)² = 1 ⇒ weight = P = 10,
        // ~38× smaller than equal-amplitude — the honest reason the harmonic floor sits far
        // closer to the single-tone floor than √385 would suggest.
        let invK = (1...10).map { 1.0 / Double($0) }
        #expect(abs(Crlb.harmonicWeight(amplitudes: invK) - 10) < 1e-9)
        #expect(Crlb.harmonicWeight(amplitudes: invK) < 385)
    }
}
