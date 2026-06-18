import Testing
import LumaDesignSystem
import TunerEngine
@testable import LUMA

@Suite struct InstrumentProfileTests {

    @Test func guitarProfileComposesGuitarPolicyAndTuning() {
        let p = InstrumentProfile.builtIn(.guitar)
        #expect(p.id == .guitar)
        #expect(p.detection == DetectionPolicy.guitar)
        #expect(p.defaultTuning.id == Tunings.guitar.id)
        #expect(p.defaultMode == .auto)
        #expect(p.defaultInput == .di)
    }

    @Test func bassProfileDefaultsToLock() {
        let p = InstrumentProfile.builtIn(.bass)
        #expect(p.id == .bass)
        #expect(p.detection == DetectionPolicy.bass)
        #expect(p.defaultTuning.id == Tunings.bass.id)
        #expect(p.defaultMode == .lock)   // bass-fix flips this from .auto
    }

    @Test func builtInIsTotalAndKeyedByInstrument() {
        for instrument in Instrument.allCases {
            #expect(InstrumentProfile.builtIn(instrument).id == instrument)
        }
    }
}
