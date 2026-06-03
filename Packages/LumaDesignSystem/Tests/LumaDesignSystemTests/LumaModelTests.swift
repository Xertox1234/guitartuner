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

    func testMidiNameOctaveHelpers() {
        XCTAssertEqual(LumaMusic.noteName(midi: 69), "A")
        XCTAssertEqual(LumaMusic.octave(midi: 69), 4)
        XCTAssertEqual(LumaMusic.noteName(midi: 61), "C\u{266F}")
        XCTAssertEqual(LumaMusic.octave(midi: 60), 4)    // C4
        XCTAssertEqual(LumaMusic.octave(midi: 23), 0)    // B0 (5-string low B)
    }

    func testTuningPresetsBuildOnChromaticCore() {
        // Drop D: lowest string down a tone to D2 (midi 38); the rest standard.
        let dropD = Tunings.guitarPresets.first { $0.id == "guitar-drop-d" }
        XCTAssertNotNil(dropD)
        XCTAssertEqual(dropD?.strings.count, 6)
        XCTAssertEqual(dropD?.strings.first?.note, "D")
        XCTAssertEqual(dropD?.strings.first?.octave, 2)
        XCTAssertEqual(dropD?.strings.first?.midi, 38)
        XCTAssertEqual(dropD?.strings.first?.idx, 6)     // lowest-pitched → idx 6
        XCTAssertEqual(dropD?.strings.last?.midi, 64)    // high E unchanged

        // 5-string bass adds a low B0 (midi 23) as the new lowest string.
        let five = Tunings.bassPresets.first { $0.id == "bass-5" }
        XCTAssertEqual(five?.strings.count, 5)
        XCTAssertEqual(five?.strings.first?.note, "B")
        XCTAssertEqual(five?.strings.first?.octave, 0)
        XCTAssertEqual(five?.strings.first?.idx, 5)

        // Standard is first in each list; the standard tuning is back-compatible.
        XCTAssertEqual(Tunings.presets(for: .guitar).first?.id, "guitar")
        XCTAssertEqual(Tunings.presets(for: .bass).first?.id, "bass")
        XCTAssertEqual(Tunings.guitar.strings.map(\.midi), [40, 45, 50, 55, 59, 64])
        XCTAssertEqual(Tunings.bass.strings.map(\.midi), [28, 33, 38, 43])
    }

    func testVisualStateFromCents() {
        XCTAssertEqual(TunerVisualState.from(cents: nil), .idle)
        XCTAssertEqual(TunerVisualState.from(cents: -10), .flat)
        XCTAssertEqual(TunerVisualState.from(cents: 10), .sharp)
        XCTAssertEqual(TunerVisualState.from(cents: 1), .tune)   // within ±3¢
        XCTAssertEqual(TunerVisualState.from(cents: -2.9), .tune)
    }
}
