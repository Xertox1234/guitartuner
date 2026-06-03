import Foundation

/// The data contract the strobe renders from — and the seam the real
/// `TunerEngine` (Plan 01) will satisfy. The prototype's simulator fills it;
/// later the engine supplies live values.
///
/// - `cents`: signed pitch error (negative = flat). Drives speed, direction,
///   convergence, and the colour blend toward mint.
/// - `phase`: reserved for the engine's live phase signal (sub-cent strobe
///   precision). The prototype integrates lateral scroll from `cents`; when the
///   engine lands, `phase` drives scroll directly. (Coordinate normalization
///   with Plan 01.)
/// - `locked`: inside the ±`LumaMusic.lockCents` window → freeze + bloom.
public struct StrobeInput: Equatable, Sendable {
    public var cents: Double
    public var phase: Double
    public var locked: Bool

    public init(cents: Double = 0, phase: Double = 0, locked: Bool = false) {
        self.cents = cents
        self.phase = phase
        self.locked = locked
    }
}
