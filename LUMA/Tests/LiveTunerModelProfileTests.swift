import Testing
import Foundation
import LumaDesignSystem
import TunerEngine
@testable import LUMA

@MainActor
@Suite struct LiveTunerModelProfileTests {

    /// Each Swift Testing run gets a fresh suite instance, so this clears the
    /// persistence keys before every test — isolating the starting state now that
    /// setInstrument/setTuning write to UserDefaults.standard (Task 10).
    init() {
        UserDefaults.standard.removeObject(forKey: "lastInstrument")
        UserDefaults.standard.removeObject(forKey: "lastTuningId")
    }

    @Test func setInstrumentSwapsProfileAndTuning() {
        let model = LiveTunerModel()
        #expect(model.profile.id == .guitar)          // launch default
        model.setInstrument(.bass)
        #expect(model.profile.id == .bass)
        #expect(model.tuning.id == Tunings.bass.id)
    }

    @Test func lockFloorComesFromActiveProfile() {
        let model = LiveTunerModel()
        // The lock floor is sourced from the live profile's DetectionPolicy band
        // table (single source of truth), not a hardcoded split.
        // Guitar low band (< 120 Hz) → 0.75, mid/high → 0.90 (former minLockConfidence).
        #expect(model.profile.detection.lockConfidence(forFrequency: 82) == 0.75)
        #expect(model.profile.detection.lockConfidence(forFrequency: 330) == 0.90)
        // Swapping instrument re-points detection to the new profile's policy.
        // Slice 1 keeps bass lock floors identical to guitar (zero-delta), so we
        // assert bass's distinct searchRange to prove the swap re-sourced the policy.
        model.setInstrument(.bass)
        #expect(model.profile.detection.searchRange == 25...420)
        #expect(model.profile.detection.lockConfidence(forFrequency: 82) == 0.75)
    }

    @Test func switchingToBassArmsLockTarget() {
        let model = LiveTunerModel()
        model.setInstrument(.bass)
        #expect(model.mode == .lock, "bass defaults to string-lock")
        let lowest = model.tuning.strings.first
        #expect(lowest != nil)
        // .lock must arm the lowest string so the strobe judges a target, not chromatic.
        #expect(model.targetNote == lowest.map { Note(midi: $0.midi) },
                "lock target armed to the lowest bass string after instrument switch")
    }

    @Test func restoresPersistedInstrumentAndTuning() {
        // Simulate a prior session having stored bass + Drop D.
        let d = UserDefaults.standard
        d.set(Instrument.bass.rawValue, forKey: "lastInstrument")
        d.set("bass-drop-d", forKey: "lastTuningId")
        defer { d.removeObject(forKey: "lastInstrument"); d.removeObject(forKey: "lastTuningId") }

        let model = LiveTunerModel()
        model.restoreLastSession()
        #expect(model.profile.id == .bass)
        #expect(model.tuning.id == "bass-drop-d")
    }
}
