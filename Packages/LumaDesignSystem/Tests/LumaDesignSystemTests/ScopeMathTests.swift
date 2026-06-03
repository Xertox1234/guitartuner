import XCTest
@testable import LumaDesignSystem

/// Verifies the stylised waveform math behind the optional `Oscilloscope`,
/// ported from `docs/design_reference/oscilloscope.jsx`.
final class ScopeMathTests: XCTestCase {

    func testVisualRate() {
        XCTAssertEqual(ScopeMath.visualRate(freq: 0), 1.2, accuracy: 1e-9)
        XCTAssertEqual(ScopeMath.visualRate(freq: 330), 2.6, accuracy: 1e-9)   // 1.2 + 1.4
        // higher notes scroll a little faster
        XCTAssertGreaterThan(ScopeMath.visualRate(freq: 440), ScopeMath.visualRate(freq: 110))
    }

    func testCycles() {
        XCTAssertEqual(ScopeMath.cycles(freq: 0), 3.2, accuracy: 1e-9)
        XCTAssertEqual(ScopeMath.cycles(freq: 200), 4.6, accuracy: 1e-9)        // 3.2 + 1.4
    }

    func testSampleBoundedAndFinite() {
        // The trace is a windowed sum of harmonics → bounded by the sum of weights
        // (1.0+0.42+0.20+0.10+0.06+0.05 = 1.83), and always finite.
        let cycles = ScopeMath.cycles(freq: 220)
        for u in stride(from: 0.0, through: 1.0, by: 0.05) {
            for phase in stride(from: 0.0, to: 6.5, by: 0.5) {
                for cents in [-50.0, 0.0, 37.5] {
                    let y = ScopeMath.sample(u: u, phase: phase, cycles: cycles, cents: cents)
                    XCTAssertLessThanOrEqual(abs(y), 1.83 + 1e-9)
                    XCTAssertFalse(y.isNaN)
                    XCTAssertFalse(y.isInfinite)
                }
            }
        }
    }
}
