import Foundation

/// One entry in a `DetectionPolicy`'s adaptive-window plan: window/hop geometry
/// plus the per-band confidence floors. Bands are ordered high→low in a policy;
/// `floorHz` is the band's lower edge and `hysteresisHz` the anti-chatter margin
/// around it. (Consolidates the former scattered AnalysisConfig band/threshold
/// constants and the app-layer lock floors — docs/todos M2/M3/M7.)
public struct BandSpec: Sendable, Equatable {
    public var window: Int
    public var hop: Int
    public var floorHz: Double
    public var hysteresisHz: Double
    public var sustainConfidence: Double
    public var lockConfidence: Double
    public var label: String

    public init(window: Int, hop: Int, floorHz: Double, hysteresisHz: Double,
                sustainConfidence: Double, lockConfidence: Double, label: String) {
        self.window = window
        self.hop = hop
        self.floorHz = floorHz
        self.hysteresisHz = hysteresisHz
        self.sustainConfidence = sustainConfidence
        self.lockConfidence = lockConfidence
        self.label = label
    }
}

/// Per-instrument detection *policy* — the small set of knobs that vary by
/// instrument or are needed to fix bass settling. The pipeline reads these
/// instead of global constants. Universal constants (nsdfPeakK, octave guard,
/// lock-precision, snap) stay in code. Built-in profiles are code-defined and
/// nothing persists a policy, so it is intentionally not `Codable`.
public struct DetectionPolicy: Sendable, Equatable {
    public var searchRange: ClosedRange<Double>
    public var bands: [BandSpec]          // ordered high→low
    public var acquire: BandSpec          // cold-start window
    public var smoothingAlpha: Double
    public var smoothingMedianCount: Int
    public var emitFloor: Double

    public init(searchRange: ClosedRange<Double>, bands: [BandSpec], acquire: BandSpec,
                smoothingAlpha: Double, smoothingMedianCount: Int, emitFloor: Double) {
        self.searchRange = searchRange
        self.bands = bands
        self.acquire = acquire
        self.smoothingAlpha = smoothingAlpha
        self.smoothingMedianCount = smoothingMedianCount
        self.emitFloor = emitFloor
    }

    /// The band for a fundamental by **pure floor lookup** (no hysteresis) —
    /// matches the former `AnalysisConfig.band(forFrequency:)`. `bands` must be
    /// ordered high→low; returns the first whose `floorHz` ≤ f0, else the lowest.
    public func band(forFrequency f0: Double) -> BandSpec {
        for b in bands where f0 >= b.floorHz { return b }
        return bands.last ?? acquire
    }

    /// Per-band lock-confidence floor for a fundamental (pure lookup) — replaces
    /// the former app-layer `minLockConfidence`.
    public func lockConfidence(forFrequency f0: Double) -> Double {
        band(forFrequency: f0).lockConfidence
    }

    /// Per-band sustain floor for a fundamental (pure lookup).
    public func sustainConfidence(forFrequency f0: Double) -> Double {
        band(forFrequency: f0).sustainConfidence
    }

    /// Guitar bands/gates + the full 27…1400 range. The headless/benchmark
    /// default — references the legacy constants directly, so it is today's
    /// behavior by construction (zero-delta).
    public static let fullRange = DetectionPolicy(
        searchRange: PitchPipeline.searchRange,
        bands: [
            BandSpec(window: AnalysisConfig.high.window,     hop: AnalysisConfig.high.hop,
                     floorHz: AnalysisConfig.highMidHz,      hysteresisHz: AnalysisConfig.highMidHysteresis,
                     sustainConfidence: AnalysisConfig.sustainMinConfidence, lockConfidence: 0.90, label: "high"),
            BandSpec(window: AnalysisConfig.mid.window,      hop: AnalysisConfig.mid.hop,
                     floorHz: AnalysisConfig.midLowHz,       hysteresisHz: AnalysisConfig.midLowHysteresis,
                     sustainConfidence: AnalysisConfig.sustainMinConfidence, lockConfidence: 0.90, label: "mid"),
            BandSpec(window: AnalysisConfig.low.window,      hop: AnalysisConfig.low.hop,
                     floorHz: AnalysisConfig.lowUltraLowHz,  hysteresisHz: AnalysisConfig.lowUltraLowHysteresis,
                     sustainConfidence: AnalysisConfig.sustainMinConfidence, lockConfidence: 0.75, label: "low"),
            BandSpec(window: AnalysisConfig.ultraLow.window, hop: AnalysisConfig.ultraLow.hop,
                     floorHz: 0,                             hysteresisHz: 0,
                     sustainConfidence: AnalysisConfig.sustainMinConfidence, lockConfidence: 0.75, label: "ultralow"),
        ],
        acquire: BandSpec(window: AnalysisConfig.acquire.window, hop: AnalysisConfig.acquire.hop,
                          floorHz: 0, hysteresisHz: 0,
                          sustainConfidence: AnalysisConfig.sustainMinConfidence, lockConfidence: 0.75, label: "acquire"),
        smoothingAlpha: AnalysisConfig.smoothingAlpha,
        smoothingMedianCount: AnalysisConfig.smoothingMedianCount,
        emitFloor: AnalysisConfig.emitFloor
    )

    /// Guitar = `.fullRange` with the search floor clamped to ~60 Hz (below Drop C's
    /// C2 = 65.4 Hz) for octave-safety. Verified zero-delta vs `.fullRange` on
    /// guitar-range stimuli (Task 5).
    public static let guitar = DetectionPolicy(
        searchRange: 60...1400,
        bands: fullRange.bands, acquire: fullRange.acquire,
        smoothingAlpha: fullRange.smoothingAlpha, smoothingMedianCount: fullRange.smoothingMedianCount,
        emitFloor: fullRange.emitFloor
    )

    /// Bass — wide search range (A0 ≈ 27.5 Hz) plus an explicit band plan that
    /// gives the bottom strings the long analysis window. E1 (41.2 Hz) and A1
    /// (55 Hz) fall in guitar's `low` 4096 window (sized for 82 Hz low E ≈ 7
    /// periods; E1 gets only ~3.5). Here the `low` band uses the 8192/2048 long
    /// window down to 40 Hz so E1/A1/D2 all get ~7+ periods, and `acquire` is the
    /// long window for octave-safe cold start. `high`/`mid` keep guitar geometry
    /// (bass rarely goes there; short windows are fine). `maxWindow` (8192, shared
    /// ring buffer) caps the long window. Bass-isolated — does not touch
    /// `.fullRange`/`.guitar`. (docs/todos/P1-bass-detection-policy-tuning.md.)
    public static let bass: DetectionPolicy = {
        let high = BandSpec(window: 1024, hop: 256, floorHz: 250, hysteresisHz: 15,
                            sustainConfidence: 0.6, lockConfidence: 0.90, label: "high")
        let mid = BandSpec(window: 2048, hop: 512, floorHz: 120, hysteresisHz: 10,
                           sustainConfidence: 0.6, lockConfidence: 0.90, label: "mid")
        // Long window down to 40 Hz so E1/A1/D2 get ~7+ periods (was guitar's 4096).
        // sustainConfidence relaxed to 0.55 (vs. guitar's 0.6) so weak-fundamental
        // clarity dips don't shatter the lock streak (RC2 defensive lever — real DI).
        // lockConfidence lowered to 0.70 to reduce visible strobe flicker on bass.
        let low = BandSpec(window: 8192, hop: 2048, floorHz: 40, hysteresisHz: 5,
                           sustainConfidence: 0.55, lockConfidence: 0.70, label: "low")
        let ultralow = BandSpec(window: 8192, hop: 2048, floorHz: 0, hysteresisHz: 0,
                                sustainConfidence: 0.55, lockConfidence: 0.70, label: "ultralow")
        let acquire = BandSpec(window: 8192, hop: 2048, floorHz: 0, hysteresisHz: 0,
                               sustainConfidence: 0.55, lockConfidence: 0.70, label: "acquire")
        return DetectionPolicy(
            searchRange: 25...420, bands: [high, mid, low, ultralow], acquire: acquire,
            smoothingAlpha: AnalysisConfig.smoothingAlpha,
            smoothingMedianCount: AnalysisConfig.smoothingMedianCount,
            emitFloor: AnalysisConfig.emitFloor
        )
    }()
}
