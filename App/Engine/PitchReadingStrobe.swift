import LumaDesignSystem
import TunerEngine

/// The seam between the engine and the design system, kept in the **app layer** so
/// `TunerEngine` stays UI-free and `LumaDesignSystem` stays logic-free (DESIGN §5).
///
/// `phase` passes straight through. The lock-confidence floor is now supplied by
/// the active `InstrumentProfile`'s `DetectionPolicy` (caller passes it in) rather
/// than a hardcoded frequency split — single source of truth (docs/todos M3).
extension PitchReading {
    /// Map a reading to the strobe's render contract, gating `locked` on the
    /// profile-supplied confidence floor.
    func strobeInput(lockCents: Double = LumaMusic.lockCents,
                     minLockConfidence: Double) -> StrobeInput {
        StrobeInput(
            cents: Float(cents),
            phase: Float(phase),
            locked: isLocked(lockCents: lockCents, minConfidence: minLockConfidence),
            isIdle: false
        )
    }
}
