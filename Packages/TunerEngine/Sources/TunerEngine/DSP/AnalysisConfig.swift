import Foundation

/// Per-range window / hop strategy. Real strings span ~31 Hz (low B) to ~1.3 kHz
/// (high frets), and the two ends want opposite things: low notes need a **long**
/// window to see 2–3 periods at all; high notes want a **short** one to stay
/// snappy. We pick the window from the current pitch band and overlap hops so the
/// readout stays responsive (DESIGN §3 "bass latency floor"; Plan 01 §4).
///
/// Tabulated at 48 kHz:
///
/// | Band     | f0 range     | Window        | Hop          | Overlap | Settles |
/// |----------|--------------|---------------|--------------|---------|---------|
/// | high     | ≥ 250 Hz     | 1024 (21 ms)  | 256 (5.3 ms) | 75 %    | ~30 ms  |
/// | mid      | 120–250 Hz   | 2048 (43 ms)  | 512 (11 ms)  | 75 %    | ~55 ms  |
/// | low      | < 120 Hz     | 4096 (85 ms)  | 1024 (21 ms) | 75 %    | ~110 ms |
/// | acquire  | (cold start) | 4096 (85 ms)  | 1024 (21 ms) | 75 %    | ~110 ms |
///
/// The low band reaches up to 120 Hz so the low guitar strings (E2 ~82, A2 ~110)
/// get a long window with ≥~7 periods — they read as low strings, not mids.
///
/// Acquisition always uses the long window so the very first lock is octave-safe
/// even on low B; once a confident pitch is known we drop to the band's window
/// for latency. Low B (~31 Hz, 32 ms period) needs ~2.6 periods → settles
/// ~100–150 ms. That's physics, documented, not a bug.
public struct AnalysisConfig: Sendable, Equatable {
    public let window: Int
    public let hop: Int
    public let label: String

    public init(window: Int, hop: Int, label: String) {
        self.window = window
        self.hop = hop
        self.label = label
    }

    public static let high    = AnalysisConfig(window: 1024, hop: 256, label: "high")
    public static let mid     = AnalysisConfig(window: 2048, hop: 512, label: "mid")
    public static let low     = AnalysisConfig(window: 4096, hop: 1024, label: "low")
    public static let acquire = AnalysisConfig(window: 4096, hop: 1024, label: "acquire")

    /// All distinct configs (acquire shares geometry with low).
    public static let all: [AnalysisConfig] = [.high, .mid, .low]

    /// The longest window any band uses — the pipeline retains at least this many
    /// recent samples so every band can be evaluated from one rolling buffer.
    public static let maxWindow = 4096

    /// Choose the band for a known fundamental. Hysteresis is applied by the
    /// caller (it nudges the boundaries) to avoid chattering at the edges.
    public static func band(forFrequency f0: Double) -> AnalysisConfig {
        if f0 >= 250 { return .high }
        if f0 >= 120 { return .mid }
        return .low
    }
}
