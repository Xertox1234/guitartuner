import Testing
import Foundation
import TunerEngine
@testable import LUMA

#if DEBUG
@MainActor
@Suite struct SessionRecordingWiringTests {
    init() {
        UserDefaults.standard.removeObject(forKey: "lastInstrument")
        UserDefaults.standard.removeObject(forKey: "lastTuningId")
    }

    @Test func stemUsesLockedTarget() {
        let model = LiveTunerModel()
        model.setMode(.lock)                       // auto-targets the lowest string
        let t = model.targetNote
        #expect(t != nil)
        #expect(model.currentFixtureStem(override: nil)
                == SessionRecorder.fixtureStem(targetNote: t, a4: model.a4, override: nil))
    }

    @Test func autoModeStemNeedsOverride() {
        let model = LiveTunerModel()
        model.setMode(.auto)
        #expect(model.currentFixtureStem(override: nil) == nil)
        #expect(model.currentFixtureStem(override: "E2") == "E2")
    }

    @Test func metadataReflectsModelState() {
        let model = LiveTunerModel()
        model.setInstrument(.bass)
        let m = model.currentMetadata()
        #expect(m.instrument == model.instrument.rawValue)
        #expect(m.a4 == model.a4)
        #expect(m.tuningId == model.tuning.id)
    }
}
#endif
