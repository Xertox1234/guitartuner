import XCTest
@testable import TunerEngine

final class NoteTests: XCTestCase {

    func testStandardFrequencies() {
        XCTAssertEqual(Pitch.frequency(midi: 69), 440, accuracy: 1e-9)        // A4
        XCTAssertEqual(Pitch.frequency(midi: 60), 261.6256, accuracy: 1e-3)   // C4
        XCTAssertEqual(Pitch.frequency(midi: 40), 82.4069, accuracy: 1e-3)    // E2
        XCTAssertEqual(Pitch.frequency(midi: 28), 41.2034, accuracy: 1e-3)    // E1
    }

    func testA4Calibration() {
        XCTAssertEqual(Pitch.frequency(midi: 69, a4: 432), 432, accuracy: 1e-9)
        // A note's frequency scales with A4.
        let e2at440 = Pitch.frequency(midi: 40, a4: 440)
        let e2at432 = Pitch.frequency(midi: 40, a4: 432)
        XCTAssertEqual(e2at432 / e2at440, 432.0 / 440.0, accuracy: 1e-9)
    }

    func testNoteNaming() {
        XCTAssertEqual(Note(midi: 69).description, "A4")
        XCTAssertEqual(Note(midi: 60).description, "C4")
        XCTAssertEqual(Note(midi: 40).description, "E2")
        XCTAssertEqual(Note(midi: 61).name, "C\u{266F}")
        XCTAssertEqual(Note(midi: 23).description, "B0")     // 5-string low B
    }

    func testNearestRoundTrip() {
        for midi in 23...100 {
            let f = Pitch.frequency(midi: midi)
            let n = Pitch.nearest(frequency: f)
            XCTAssertEqual(n?.note.midi, midi)
            XCTAssertEqual(n?.cents ?? 99, 0, accuracy: 1e-6)
        }
    }

    func testNearestCentsSign() {
        // 20 cents sharp of A4.
        let sharp = Pitch.nearest(frequency: 440 * pow(2, 20.0 / 1200))
        XCTAssertEqual(sharp?.note.midi, 69)
        XCTAssertEqual(sharp?.cents ?? 0, 20, accuracy: 0.01)
        // 30 cents flat of E2.
        let flat = Pitch.nearest(frequency: Pitch.frequency(midi: 40) * pow(2, -30.0 / 1200))
        XCTAssertEqual(flat?.note.midi, 40)
        XCTAssertEqual(flat?.cents ?? 0, -30, accuracy: 0.01)
    }

    func testNearestRejectsNonPositive() {
        XCTAssertNil(Pitch.nearest(frequency: 0))
        XCTAssertNil(Pitch.nearest(frequency: -10))
    }

    func testReadingLock() {
        let inTune = PitchReading(frequency: 440, note: Note(midi: 69), cents: 1.5,
                                  confidence: 0.95, phase: 0, timestamp: 0)
        XCTAssertTrue(inTune.isLocked())
        let off = PitchReading(frequency: 440, note: Note(midi: 69), cents: 8,
                               confidence: 0.95, phase: 0, timestamp: 0)
        XCTAssertFalse(off.isLocked())
        let unsure = PitchReading(frequency: 440, note: Note(midi: 69), cents: 1,
                                  confidence: 0.4, phase: 0, timestamp: 0)
        XCTAssertFalse(unsure.isLocked())
    }
}
