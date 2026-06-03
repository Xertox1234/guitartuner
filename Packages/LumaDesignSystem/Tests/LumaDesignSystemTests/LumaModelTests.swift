import XCTest
@testable import LumaDesignSystem

/// Sanity checks for the small render-support model (no DSP). Run on macOS —
/// SwiftUI isn't available on Linux.
final class LumaModelTests: XCTestCase {

    func testNoteParts() {
        XCTAssertEqual(LumaMusic.parts("A").letter, "A")
        XCTAssertEqual(LumaMusic.parts("A").accidental, "")
        let sharp = LumaMusic.parts("C\u{266F}")
        XCTAssertEqual(sharp.letter, "C")
        XCTAssertEqual(sharp.accidental, "\u{266F}")
    }

    func testFrequencyOfA4() {
        XCTAssertEqual(LumaMusic.frequency(midi: 69), 440, accuracy: 0.0001)
        XCTAssertEqual(LumaMusic.frequency(midi: 69, a4: 432), 432, accuracy: 0.0001)
        // Low E (E2, midi 40) ≈ 82.41 Hz at A=440.
        XCTAssertEqual(LumaMusic.frequency(midi: 40), 82.41, accuracy: 0.01)
    }

    func testNearestNote() {
        let n = LumaMusic.nearest(frequency: 440)
        XCTAssertEqual(n.name, "A")
        XCTAssertEqual(n.octave, 4)
        XCTAssertEqual(n.cents, 0)
        XCTAssertEqual(n.midi, 69)
    }

    func testTuningsLayout() {
        // Guitar: 6 strings, rendered low→high.
        XCTAssertEqual(Tunings.guitar.strings.count, 6)
        XCTAssertEqual(Tunings.guitar.strings.first?.note, "E")
        XCTAssertEqual(Tunings.guitar.strings.first?.octave, 2)
        XCTAssertEqual(Tunings.guitar.strings.last?.midi, 64)
        // Bass: 4 strings, low E1.
        XCTAssertEqual(Tunings.bass.strings.count, 4)
        XCTAssertEqual(Tunings.bass.strings.first?.midi, 28)
        XCTAssertEqual(Tunings.standard(for: .bass).id, "bass")
    }

    func testVisualStateFromCents() {
        XCTAssertEqual(TunerVisualState.from(cents: nil), .idle)
        XCTAssertEqual(TunerVisualState.from(cents: -10), .flat)
        XCTAssertEqual(TunerVisualState.from(cents: 10), .sharp)
        XCTAssertEqual(TunerVisualState.from(cents: 1), .tune)   // within ±3¢
        XCTAssertEqual(TunerVisualState.from(cents: -2.9), .tune)
    }
}
