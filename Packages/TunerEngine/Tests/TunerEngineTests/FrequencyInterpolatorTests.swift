import XCTest
@testable import TunerEngine

/// Proves the §2.2 interpolation ranking: parabolic ≫ log-parabolic ≫ Candan,
/// and that Candan reaches the sub-0.02 ¢ (near-CRLB) regime P1 needs.
final class FrequencyInterpolatorTests: XCTestCase {
    let fs = 48_000.0
    let N = 4096

    /// Rectangular-window DFT bin `m` of a pure tone at fractional bin `m0+δ`.
    private func rectBin(_ delta: Double, m0: Double, bin m: Double) -> (re: Double, im: Double) {
        let f = (m0 + delta) * fs / Double(N)
        let frame = (0..<N).map { Float(cos(2 * .pi * f / fs * Double($0))) }
        return StrobePhase.bin(frame, frequency: m * fs / Double(N), sampleRate: fs)
    }

    /// Hann-window magnitude at bin `m`.
    private func hannMag(_ delta: Double, m0: Double, bin m: Double) -> Double {
        let f = (m0 + delta) * fs / Double(N)
        let frame = (0..<N).map { i -> Float in
            let w = 0.5 - 0.5 * cos(2 * .pi * Double(i) / Double(N - 1))
            return Float(w * cos(2 * .pi * f / fs * Double(i)))
        }
        let c = StrobePhase.bin(frame, frequency: m * fs / Double(N), sampleRate: fs)
        return (c.re * c.re + c.im * c.im).squareRoot()
    }

    private func cents(_ estBin: Double, _ trueBin: Double) -> Double {
        1200 * log2((estBin * fs / Double(N)) / (trueBin * fs / Double(N)))
    }

    func testCandanIsNearCRLB() {
        let m0 = 200.0
        var worst = 0.0
        for d in stride(from: -0.45, through: 0.45, by: 0.05) {
            let est = m0 + FrequencyInterpolator.candan(
                rectBin(d, m0: m0, bin: m0 - 1), rectBin(d, m0: m0, bin: m0), rectBin(d, m0: m0, bin: m0 + 1), n: N)
            worst = max(worst, abs(cents(est, m0 + d)))
        }
        XCTAssertLessThan(worst, 0.02, "Candan worst-case \(worst)¢ should be near-CRLB")
    }

    func testParabolicAndLogReproduceProbeRanking() {
        let m0 = 200.0
        var worstLin = 0.0, worstLog = 0.0
        for d in stride(from: -0.45, through: 0.45, by: 0.05) {
            let a = hannMag(d, m0: m0, bin: m0 - 1), b = hannMag(d, m0: m0, bin: m0), c = hannMag(d, m0: m0, bin: m0 + 1)
            worstLin = max(worstLin, abs(cents(m0 + FrequencyInterpolator.parabolic(a, b, c), m0 + d)))
            worstLog = max(worstLog, abs(cents(m0 + FrequencyInterpolator.logParabolic(a, b, c), m0 + d)))
        }
        // Bounds, not exact maxima — robust to small cross-platform libm/trig
        // differences while still pinning the §2.2 ranking (~0.46 / ~0.14 ¢).
        XCTAssertTrue((0.40...0.52).contains(worstLin), "parabolic ~0.46¢, got \(worstLin)")
        XCTAssertTrue((0.10...0.18).contains(worstLog), "log-parabolic ~0.14¢, got \(worstLog)")
        XCTAssertLessThan(worstLog, worstLin)   // the primary invariant
    }

    func testInterpolatorsZeroOnCentredPeak() {
        // A perfectly bin-centred, symmetric peak interpolates to δ = 0.
        XCTAssertEqual(FrequencyInterpolator.parabolic(0.5, 1.0, 0.5), 0, accuracy: 1e-12)
        XCTAssertEqual(FrequencyInterpolator.logParabolic(0.5, 1.0, 0.5), 0, accuracy: 1e-12)
        XCTAssertEqual(FrequencyInterpolator.candan((1, 0), (2, 0), (1, 0), n: N), 0, accuracy: 1e-12)
    }

    func testDegenerateInputsAreSafe() {
        XCTAssertEqual(FrequencyInterpolator.parabolic(1, 1, 1), 0)               // flat → no peak
        XCTAssertEqual(FrequencyInterpolator.candan((0, 0), (0, 0), (0, 0), n: N), 0)  // silence
        XCTAssertTrue(abs(FrequencyInterpolator.parabolic(0, 1, 9)) <= 0.5)        // clamped
    }
}
