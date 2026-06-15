import Foundation

/// Per-range window / hop strategy. Real strings span ~31 Hz (low B) to ~1.3 kHz
/// (high frets), and the two ends want opposite things: low notes need a **long**
/// window to see 2–3 periods at all; high notes want a **short** one to stay
/// snappy. We pick the window from the current pitch band and overlap hops so the
/// readout stays responsive (DESIGN §3 "bass latency floor"; Plan 01 §4).
///
/// Tabulated at 48 kHz:
///
/// | Band     | f0 range     | Window         | Hop           | Overlap | Settles  |
/// |----------|--------------|----------------|---------------|---------|----------|
/// | high     | ≥ 250 Hz     | 1024 (21 ms)   | 256 (5.3 ms)  | 75 %    | ~30 ms   |
/// | mid      | 120–250 Hz   | 2048 (43 ms)   | 512 (11 ms)   | 75 %    | ~55 ms   |
/// | low      | 40–120 Hz    | 4096 (85 ms)   | 1024 (21 ms)  | 75 %    | ~110 ms  |
/// | ultralow | < 40 Hz      | 8192 (170 ms)  | 2048 (43 ms)  | 75 %    | ~200 ms  |
/// | acquire  | (cold start) | 4096 (85 ms)   | 1024 (21 ms)  | 75 %    | ~110 ms  |
///
/// The ultra-low band (< 40 Hz) targets the 5-string bass low B (B0 ~31 Hz). At
/// N=4096 the inter-partial spacing for B0 is only 2.6 bins, causing ~2–4 ¢
/// inter-partial leakage in the Candan/log-parabolic triplet estimates. N=8192
/// doubles the resolution (5.2 bins spacing, ~0.5 ¢ leakage) and promotes B0 n=2
/// (previously at bin 5.3, below minBin=6) to bin 10.6 — now above the gate.
///
/// The low band reaches up to 120 Hz so the low guitar strings (E2 ~82, A2 ~110)
/// get a long window with ≥~7 periods — they read as low strings, not mids.
///
/// Acquisition always uses the long window so the very first lock is octave-safe
/// even on low B; once a confident pitch is known we drop to the band's window
/// for latency. Low B (~31 Hz, 32 ms period) with ultralow window (170 ms) covers
/// ~5 periods — well resolved for MPM and the HarmonicEstimator comb.
public struct AnalysisConfig: Sendable, Equatable {
    public let window: Int
    public let hop: Int
    public let label: String

    public init(window: Int, hop: Int, label: String) {
        self.window = window
        self.hop = hop
        self.label = label
    }

    public static let high     = AnalysisConfig(window: 1024, hop: 256,  label: "high")
    public static let mid      = AnalysisConfig(window: 2048, hop: 512,  label: "mid")
    public static let low      = AnalysisConfig(window: 4096, hop: 1024, label: "low")
    public static let ultraLow = AnalysisConfig(window: 8192, hop: 2048, label: "ultralow")
    public static let acquire  = AnalysisConfig(window: 4096, hop: 1024, label: "acquire")

    /// All distinct configs (acquire shares geometry with low).
    public static let all: [AnalysisConfig] = [.high, .mid, .low, .ultraLow]

    /// The longest window any band uses — the pipeline retains at least this many
    /// recent samples so every band can be evaluated from one rolling buffer.
    public static let maxWindow = 8192

    /// Band-transition centre frequencies (Hz). Hysteresis is applied around each.
    public static let highMidHz:      Double = 250
    public static let midLowHz:       Double = 120  // also gates spectral-refine in PitchPipeline
    public static let lowUltraLowHz:  Double = 40

    /// ±Hysteresis window around each boundary. Prevents chattering when f0 hovers
    /// at a band edge. Derived thresholds in PitchPipeline.nextConfig must use these.
    public static let highMidHysteresis:     Double = 15
    public static let midLowHysteresis:      Double = 10
    public static let lowUltraLowHysteresis: Double = 5

    // MARK: – Gate & lock thresholds

    /// PhaseIntegrator LS-fit residual must be ≤ this before reporting LOCKED state.
    /// Typical settled clean-bass: ~0.12¢; decay-glide early window: ≥2¢.
    public static let lockPrecisionThreshold: Double = 1.0

    /// Clarity (NSDF normalised peak height) below which a frame is treated as
    /// unvoiced. Used as emit floor in PitchPipeline and as octave-rescue fallback
    /// threshold in PitchDetector.
    public static let emitFloor: Double = 0.5

    /// Minimum clarity for SustainGate to count a frame as voiced.
    /// Sits below clean clarity (~0.95) and inharmonic-low (~0.7–0.85) but above noise (~0.3–0.5).
    public static let sustainMinConfidence: Double = 0.6

    /// McLeod NSDF peak-selection fraction: first key-maximum clearing k·nmax.
    /// k≈0.9 is the octave-safe value from McLeod & Wyvill (2005).
    public static let nsdfPeakK: Double = 0.9

    /// EMA smoothing factor for FrequencySmoother. Higher = snappier but noisier.
    public static let smoothingAlpha: Double = 0.35

    /// Jumps larger than this (¢) bypass EMA smoothing in FrequencySmoother (new-note transient).
    public static let smoothingSnapCents: Double = 120

    /// Minimum NSDF clarity required to accept a detection that is ≥ one octave from
    /// the tracked frequency. Below this threshold the jump is treated as an alias or
    /// harmonic artefact and the frame is handled as unvoiced.
    public static let octaveGuardMinClarity: Double = 0.95

    /// Choose the band for a known fundamental. Hysteresis is applied by the
    /// caller (it nudges the boundaries) to avoid chattering at the edges.
    public static func band(forFrequency f0: Double) -> AnalysisConfig {
        if f0 >= highMidHz    { return .high }
        if f0 >= midLowHz     { return .mid }
        if f0 >= lowUltraLowHz { return .low }
        return .ultraLow
    }
}
