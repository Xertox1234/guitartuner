import LumaDesignSystem
import TunerEngine

/// The seam between the engine and the design system, kept in the **app layer** so
/// `TunerEngine` stays UI-free and `LumaDesignSystem` stays logic-free (DESIGN §5).
///
/// `phase` passes straight through: the engine defines it as a normalized 0…1
/// cycle position of the tracked fundamental against the nearest-note reference,
/// which is exactly what the Aurora strobe scrolls by (`phaseScroll: true`).
extension PitchReading {
    /// Map a reading to the strobe's render contract.
    func strobeInput(lockCents: Double = LumaMusic.lockCents) -> StrobeInput {
        let minConf = frequency < 120 ? 0.75 : 0.9
        return StrobeInput(
            cents: cents,
            phase: phase,
            locked: isLocked(lockCents: lockCents, minConfidence: minConf)
        )
    }
}
