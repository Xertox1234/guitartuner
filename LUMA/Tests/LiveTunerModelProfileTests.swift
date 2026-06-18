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
        model.setInstrument(.guitar)
        // Guitar low band (< 120 Hz) → 0.75, mid/high → 0.90 (former minLockConfidence).
        #expect(model.profile.detection.lockConfidence(forFrequency: 82) == 0.75)
        #expect(model.profile.detection.lockConfidence(forFrequency: 330) == 0.90)
    }
}
