import XCTest
@testable import LumaDesignSystem

/// Verifies the strobe math ported from `strobe-aurora.jsx` / `strobe-core.jsx`.
final class StrobeMathTests: XCTestCase {

    func testProximity() {
        XCTAssertEqual(StrobeMath.proximity(cents: 0), 1, accuracy: 1e-9)
        XCTAssertEqual(StrobeMath.proximity(cents: 9), 0.5, accuracy: 1e-9)
        XCTAssertEqual(StrobeMath.proximity(cents: -9), 0.5, accuracy: 1e-9)   // sign-independent
        XCTAssertEqual(StrobeMath.proximity(cents: 18), 0, accuracy: 1e-9)
        XCTAssertEqual(StrobeMath.proximity(cents: 40), 0, accuracy: 1e-9)     // clamped at 0
    }

    func testScrollSpeed() {
        XCTAssertEqual(StrobeMath.scrollSpeed(cents: 0, lock: 0), 0, accuracy: 1e-9)
        XCTAssertEqual(StrobeMath.scrollSpeed(cents: 30, lock: 1), 0, accuracy: 1e-9)  // frozen at lock
        // sharp scrolls one way, flat the other
        XCTAssertGreaterThan(StrobeMath.scrollSpeed(cents: 10, lock: 0), 0)
        XCTAssertLessThan(StrobeMath.scrollSpeed(cents: -10, lock: 0), 0)
        XCTAssertEqual(StrobeMath.scrollSpeed(cents: 10, lock: 0), 10 * 0.0009 * 60, accuracy: 1e-9)
    }

    func testSpread() {
        XCTAssertEqual(StrobeMath.spread(prox: 0, lock: 0), 0.5, accuracy: 1e-9)
        XCTAssertEqual(StrobeMath.spread(prox: 1, lock: 0), 0.16, accuracy: 1e-9)  // converged
        XCTAssertEqual(StrobeMath.spread(prox: 0, lock: 1), 0.16, accuracy: 1e-9)  // lock also converges
    }

    func testRingSpeed() {
        XCTAssertEqual(StrobeMath.ringSpeed(cents: 0, lock: 0), 0, accuracy: 1e-9)
        XCTAssertEqual(StrobeMath.ringSpeed(cents: 30, lock: 1), 0, accuracy: 1e-9)   // frozen at lock
        // sharp rotates one way, flat the other
        XCTAssertGreaterThan(StrobeMath.ringSpeed(cents: 10, lock: 0), 0)
        XCTAssertLessThan(StrobeMath.ringSpeed(cents: -10, lock: 0), 0)
        XCTAssertEqual(StrobeMath.ringSpeed(cents: 10, lock: 0), 10 * 0.010 * 60, accuracy: 1e-9)
    }

    func testMarkEnvelope() {
        // Peaks at the top of the ring (a = −π/2), dimmest at the bottom (a = +π/2).
        XCTAssertEqual(StrobeMath.markEnvelope(angle: -.pi / 2), 1.0, accuracy: 1e-9)
        XCTAssertEqual(StrobeMath.markEnvelope(angle: .pi / 2), 0.35, accuracy: 1e-9)
        XCTAssertEqual(StrobeMath.markEnvelope(angle: 0), 0.35 + 0.65 * pow(0.5, 1.5), accuracy: 1e-9)
        // Always within [0.35, 1] across a full revolution.
        for deg in stride(from: 0.0, to: 360.0, by: 7.0) {
            let env = StrobeMath.markEnvelope(angle: deg * .pi / 180)
            XCTAssertGreaterThanOrEqual(env, 0.35 - 1e-9)
            XCTAssertLessThanOrEqual(env, 1.0 + 1e-9)
        }
    }

    func testGaugeAngle() {
        XCTAssertEqual(StrobeMath.gaugeAngle(cents: 0), 0, accuracy: 1e-9)
        XCTAssertEqual(StrobeMath.gaugeAngle(cents: 50), 122, accuracy: 1e-9)
        XCTAssertEqual(StrobeMath.gaugeAngle(cents: -50), -122, accuracy: 1e-9)
        XCTAssertEqual(StrobeMath.gaugeAngle(cents: 100), 122, accuracy: 1e-9)   // clamped
        XCTAssertEqual(StrobeMath.gaugeAngle(cents: 25), 61, accuracy: 1e-9)
    }

    func testRGBHex() {
        let mint = RGB(hex: 0x28F0C0)
        XCTAssertEqual(mint.r, 0x28 / 255.0, accuracy: 1e-9)
        XCTAssertEqual(mint.g, 0xF0 / 255.0, accuracy: 1e-9)
        XCTAssertEqual(mint.b, 0xC0 / 255.0, accuracy: 1e-9)
        let half = mix(RGB(0, 0, 0), RGB(1, 1, 1), 0.5)
        XCTAssertEqual(half.r, 0.5, accuracy: 1e-9)
    }
}

/// Deterministic checks on the simulator (random convergence paths excluded).
final class TunerSimulatorTests: XCTestCase {

    func testManualClampAndLock() {
        let sim = TunerSimulator(instrument: .guitar)
        sim.setManual(100)
        XCTAssertEqual(sim.cents, 50, accuracy: 1e-9)   // clamped to trackCents
        XCTAssertFalse(sim.locked)
        sim.setManual(-200)
        XCTAssertEqual(sim.cents, -50, accuracy: 1e-9)
        sim.setManual(1)
        XCTAssertTrue(sim.locked)                        // within ±3¢
    }

    func testInstrumentSwitchResetsToMiddleString() {
        let sim = TunerSimulator(instrument: .guitar)
        sim.setInstrument(.bass)
        XCTAssertEqual(sim.instrument, .bass)
        // bass has 4 strings (idx 4..1); middle index 2 → idx 2 (D2)
        XCTAssertEqual(sim.activeString.note, "D")
        XCTAssertTrue(sim.tuning.strings.contains { $0.idx == sim.stringIdx })
    }

    func testDisplayedFrequencyAtZeroCents() {
        let sim = TunerSimulator(instrument: .guitar)
        sim.setManual(0)
        let expected = LumaMusic.frequency(midi: sim.activeString.midi, a4: 440)
        XCTAssertEqual(sim.displayedFrequency(a4: 440), expected, accuracy: 1e-6)
    }
}

/// The hero-strobe selection contract (Settings picker + `@AppStorage` persistence).
final class StrobeStyleTests: XCTestCase {

    func testAuroraIsTheDefaultAndFirstOption() {
        // Aurora is the documented default — leftmost in the segmented picker.
        XCTAssertEqual(StrobeStyle.allCases.first, .aurora)
        XCTAssertEqual(StrobeStyle.allCases, [.aurora, .radial])
    }

    func testLabelsAndIdentity() {
        XCTAssertEqual(StrobeStyle.aurora.label, "Aurora")
        XCTAssertEqual(StrobeStyle.radial.label, "Radial")
        XCTAssertEqual(StrobeStyle.radial.id, StrobeStyle.radial.rawValue)
    }

    func testRawValueRoundTripForAppStorage() {
        // The persisted raw string must survive a round-trip; unknown values are nil
        // (callers fall back to the .aurora default).
        for style in StrobeStyle.allCases {
            XCTAssertEqual(StrobeStyle(rawValue: style.rawValue), style)
        }
        XCTAssertNil(StrobeStyle(rawValue: "spinner"))
    }
}
