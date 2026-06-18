import Testing
import LumaDesignSystem
import TunerEngine
@testable import LUMA

@MainActor
@Suite struct LiveTunerModelProfileTests {

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
}
