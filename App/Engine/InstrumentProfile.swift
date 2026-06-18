import LumaDesignSystem
import TunerEngine

/// The unifying, first-class instrument profile (DESIGN: instrument-profiles §4-5).
/// Lives in the App layer — the only place allowed to compose a `Tuning`
/// (LumaDesignSystem) with a `DetectionPolicy` (TunerEngine) plus UX defaults,
/// since neither package may import the other. Built-in profiles are
/// code-defined (not persisted); custom *tunings* remain `TuningCard`'s job.
struct InstrumentProfile: Identifiable, Sendable {
    let id: Instrument
    var displayName: String
    var defaultTuning: Tuning
    var detection: DetectionPolicy
    var defaultMode: TargetMode
    var defaultInput: InputKind

    /// The code-defined built-in profile for an instrument.
    static func builtIn(_ instrument: Instrument) -> InstrumentProfile {
        switch instrument {
        case .guitar:
            return InstrumentProfile(
                id: .guitar, displayName: "Guitar",
                defaultTuning: Tunings.guitar, detection: .guitar,
                defaultMode: .auto, defaultInput: .di
            )
        case .bass:
            return InstrumentProfile(
                id: .bass, displayName: "Bass",
                defaultTuning: Tunings.bass, detection: .bass,
                // Slice 1: bass stays .auto. The deferred bass-fix flips this to .lock.
                defaultMode: .auto, defaultInput: .di
            )
        }
    }
}
