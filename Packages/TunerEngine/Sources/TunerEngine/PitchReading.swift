import Foundation

/// One precise pitch estimate from the engine — the public output type.
///
/// - `frequency`: estimated fundamental in Hz (sub-cent refined).
/// - `note`: nearest equal-tempered note at the engine's current `a4`.
/// - `cents`: signed offset from `note` (negative = flat), typically −50…+50.
/// - `confidence`: 0…1 periodicity/clarity. Low during the pluck attack and in
///   noise; high on a clean sustain. The sustain gate uses it.
/// - `phase`: the **strobe phase** — a normalized 0…1 cycle position of the
///   tracked fundamental measured against the nearest-note reference oscillator
///   (see `StrobePhase`). On pitch it stands still; off pitch it advances at the
///   beat rate (∝ the frequency error). The strobe scrolls by Δphase between
///   readings — this *is* the true-strobe signal (DESIGN §3, EXPERIENCE §2).
/// - `timestamp`: seconds, monotonic from the engine's audio clock (the time of
///   the analysed window's centre).
/// - `inharmonicityB`: estimated string stiffness coefficient B in the model
///   `fₙ = n·f0·√(1+B·n²)` (Plan 06 §5.3). `nil` for mid/high range readings
///   and while the harmonic fit has not yet converged. Non-nil only when the P2
///   harmonic estimator ran successfully on this reading (bass, f0 < 120 Hz).
public struct PitchReading: Sendable, Equatable {
    public let frequency: Double
    public let note: Note
    public let cents: Double
    public let confidence: Double
    public let phase: Double
    public let timestamp: TimeInterval
    public let inharmonicityB: Double?
    /// Estimated ±σ of `cents` (and `frequency`) in cents, from the P3 phase-slope
    /// integrator. `nil` while acquiring or when the integrator has not yet converged.
    /// Non-nil implies `isLockIntegrated == true`.
    public let precisionCents: Double?
    /// `true` when `frequency` (and `cents`) come from the P3 long-window phase-slope
    /// integrator rather than the per-hop P1/P2 refine. Implies sub-0.05 ¢ σ on a
    /// clean sustained note.
    public let isLockIntegrated: Bool

    public init(
        frequency: Double,
        note: Note,
        cents: Double,
        confidence: Double,
        phase: Double,
        timestamp: TimeInterval,
        inharmonicityB: Double? = nil,
        precisionCents: Double? = nil,
        isLockIntegrated: Bool = false
    ) {
        self.frequency = frequency
        self.note = note
        self.cents = cents
        self.confidence = confidence
        self.phase = phase
        self.timestamp = timestamp
        self.inharmonicityB = inharmonicityB
        self.precisionCents = precisionCents
        self.isLockIntegrated = isLockIntegrated
    }

    /// Confidence floor for mid/high strings (f0 ≥ 120 Hz). Bass uses a lower
    /// per-band value in the app layer (see PitchReadingStrobe.minLockConfidence).
    public static let defaultLockConfidence: Double = 0.9

    /// In-tune window half-width in cents. Matches LumaDesignSystem.LumaMusic.lockCents
    /// (both are 3.0); the two packages can't share a constant directly (no cross-dep),
    /// so LUMATests asserts equality as a coupling guard.
    public static let lockCents: Double = 3.0

    /// `true` when within the in-tune window (±`lockCents`) and confident enough
    /// to trust. Mirrors the design system's ±3¢ lock so the strobe's freeze and
    /// the engine agree.
    public func isLocked(lockCents: Double = Self.lockCents, minConfidence: Double = Self.defaultLockConfidence) -> Bool {
        abs(cents) <= lockCents && confidence >= minConfidence
    }
}

/// Which input the engine should prefer. A clean wired DI is what makes
/// "strobe-grade" reachable; the mic is the graceful fallback (DESIGN §3).
public enum InputPreference: String, Sendable, CaseIterable {
    /// Prefer a wired DI / interface if present, else the mic.
    case auto
    /// Force the DI / external interface; error if none is available.
    case di
    /// Force the built-in microphone.
    case mic
}
