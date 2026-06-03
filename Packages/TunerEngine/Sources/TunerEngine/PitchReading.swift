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
public struct PitchReading: Sendable, Equatable {
    public let frequency: Double
    public let note: Note
    public let cents: Double
    public let confidence: Double
    public let phase: Double
    public let timestamp: TimeInterval

    public init(
        frequency: Double,
        note: Note,
        cents: Double,
        confidence: Double,
        phase: Double,
        timestamp: TimeInterval
    ) {
        self.frequency = frequency
        self.note = note
        self.cents = cents
        self.confidence = confidence
        self.phase = phase
        self.timestamp = timestamp
    }

    /// `true` when within the in-tune window (±`lockCents`) and confident enough
    /// to trust. Mirrors the design system's ±3¢ lock so the strobe's freeze and
    /// the engine agree.
    public func isLocked(lockCents: Double = 3.0, minConfidence: Double = 0.9) -> Bool {
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
