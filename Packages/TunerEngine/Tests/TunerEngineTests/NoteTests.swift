import Foundation
import Testing
@testable import TunerEngine

@Suite struct NoteTests {

    @Test func standardFrequencies() {
        #expect(abs(Pitch.frequency(midi: 69) - 440) < 1e-9)         // A4
        #expect(abs(Pitch.frequency(midi: 60) - 261.6256) < 1e-3)    // C4
        #expect(abs(Pitch.frequency(midi: 40) - 82.4069) < 1e-3)     // E2
        #expect(abs(Pitch.frequency(midi: 28) - 41.2034) < 1e-3)     // E1
    }

    @Test func a4Calibration() {
        #expect(abs(Pitch.frequency(midi: 69, a4: 432) - 432) < 1e-9)
        let e2at440 = Pitch.frequency(midi: 40, a4: 440)
        let e2at432 = Pitch.frequency(midi: 40, a4: 432)
        #expect(abs(e2at432 / e2at440 - 432.0 / 440.0) < 1e-9)
    }

    @Test func noteNaming() {
        #expect(Note(midi: 69).description == "A4")
        #expect(Note(midi: 60).description == "C4")
        #expect(Note(midi: 40).description == "E2")
        #expect(Note(midi: 61).name == "C\u{266F}")
        #expect(Note(midi: 23).description == "B0")     // 5-string low B
    }

    @Test func nearestRoundTrip() {
        for midi in 23...100 {
            let f = Pitch.frequency(midi: midi)
            let n = Pitch.nearest(frequency: f)
            #expect(n?.note.midi == midi)
            #expect(abs(n?.cents ?? 99) < 1e-6)
        }
    }

    @Test func nearestCentsSign() {
        // 20 cents sharp of A4.
        let sharp = Pitch.nearest(frequency: 440 * pow(2, 20.0 / 1200))
        #expect(sharp?.note.midi == 69)
        #expect(abs((sharp?.cents ?? 0) - 20) < 0.01)
        // 30 cents flat of E2.
        let flat = Pitch.nearest(frequency: Pitch.frequency(midi: 40) * pow(2, -30.0 / 1200))
        #expect(flat?.note.midi == 40)
        #expect(abs((flat?.cents ?? 0) - (-30)) < 0.01)
    }

    @Test func nearestRejectsNonPositive() {
        #expect(Pitch.nearest(frequency: 0) == nil)
        #expect(Pitch.nearest(frequency: -10) == nil)
    }

    @Test func centsRelativeToTargetNote() {
        let a4 = Note(midi: 69)
        #expect(abs(a4.cents(of: 440)) < 1e-6)
        #expect(abs(a4.cents(of: 440 * pow(2, 10.0 / 1200)) - 10) < 1e-6)   // sharp
        #expect(abs(a4.cents(of: 440 * pow(2, -25.0 / 1200)) - (-25)) < 1e-6) // flat
        #expect(abs(Note(midi: 69).cents(of: 432, a4: 432)) < 1e-6)
        let b0 = Note(midi: 23)
        #expect(b0.cents(of: b0.frequency() * 1.01) > 0)
        #expect(b0.cents(of: 0) == 0)                                          // non-positive guarded
    }

    @Test func readingLock() {
        let inTune = PitchReading(frequency: 440, note: Note(midi: 69), cents: 1.5,
                                  confidence: 0.95, phase: 0, timestamp: 0)
        #expect(inTune.isLocked())
        let off = PitchReading(frequency: 440, note: Note(midi: 69), cents: 8,
                               confidence: 0.95, phase: 0, timestamp: 0)
        #expect(!off.isLocked())
        let unsure = PitchReading(frequency: 440, note: Note(midi: 69), cents: 1,
                                  confidence: 0.4, phase: 0, timestamp: 0)
        #expect(!unsure.isLocked())
    }
}
