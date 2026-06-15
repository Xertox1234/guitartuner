import Foundation

/// Estimates the per-device sample-clock error (ppm) by comparing accumulated
/// sample counts against wall-clock time (Plan 06 P4 §7.1).
///
/// ### Why this matters
/// Every device's crystal oscillator runs at `nominal ± ppm_error`. At 44 ppm
/// (a real measured sound card), 1 ¢ = 577.8 ppm implies ±0.076 ¢ of absolute
/// error that cannot be measured from the signal alone. Relative (strobe) accuracy
/// is immune — the clock error cancels. Only absolute "is A really 440 Hz?" claims
/// are affected. Calibrating removes this floor.
///
/// ### Measurement method
/// Count samples at the nominal rate vs wall-clock time over ≥30 s:
///   `ppm = (sampleCount / duration_s / nominalRate - 1) × 1_000_000`
///
/// Wall time is `CACurrentMediaTime()` (mach_absolute_time, ≤10 ppm accuracy on
/// Apple Silicon). With 30 s accumulation and 1 ppm wall error, total uncertainty
/// ≈ 1–2 ppm ≈ 0.002 ¢ — well inside the 0.02 ¢ calibrated-mode spec.
///
/// ### Usage
/// Create one instance per capture session. Call `observe(sampleCount:wallTime:)`
/// every time the capture tap delivers a batch of samples. Once `isConverged`
/// is true, `correctionFactor` is stable and can be applied:
/// ```swift
/// let actualHz = nominalHz * calibration.correctionFactor
/// ```
public final class ClockCalibration: @unchecked Sendable {

    // MARK: - Convergence criteria

    /// Minimum wall-clock duration before `isConverged` can be true.
    public static let minCalibrationDuration: Double = 30.0   // seconds

    /// ppm uncertainty target (1σ) before declaring converged.
    /// With ≥30 s and ≤1 ppm wall-clock error: achievable in practice.
    public static let convergedUncertaintyPPM: Double = 3.0

    // MARK: - State

    private let nominalRate: Double
    private var t0: Double?
    private var totalSamples: Int64 = 0

    /// Accumulated wall-clock seconds since `startMeasurement` was called.
    private var elapsedSeconds: Double = 0

    // MARK: - Public interface

    public init(nominalRate: Double) {
        self.nominalRate = nominalRate
    }

    /// Mark the start of the measurement window. Call once when capture begins
    /// (e.g., at `AVAudioEngine.start()` time). `wallTime` is typically
    /// `CACurrentMediaTime()`.
    public func startMeasurement(wallTime: Double) {
        t0 = wallTime
        totalSamples = 0
        elapsedSeconds = 0
    }

    /// Feed the sample count from one audio buffer. Call from the audio tap on
    /// every buffer delivery.
    ///
    /// - Parameters:
    ///   - sampleCount: Number of samples in this buffer.
    ///   - wallTime:    Delivery time in seconds (e.g. `CACurrentMediaTime()`).
    public func observe(sampleCount: Int, wallTime: Double) {
        guard let t0 else { return }
        totalSamples += Int64(sampleCount)
        elapsedSeconds = wallTime - t0
    }

    /// Measured sample-rate error in parts-per-million.
    /// Positive = crystal runs fast (measured rate > nominal).
    /// Returns 0 before enough data has accumulated.
    public var measuredPPM: Double {
        guard elapsedSeconds >= 1.0, totalSamples > 0 else { return 0.0 }
        let measuredRate = Double(totalSamples) / elapsedSeconds
        return (measuredRate / nominalRate - 1.0) * 1_000_000
    }

    /// 1σ uncertainty of `measuredPPM`, dominated by wall-clock accuracy (~1–2 ppm).
    /// Shrinks as `elapsedSeconds` grows: proportional to `1/√(elapsedSeconds)`.
    public var uncertaintyPPM: Double {
        guard elapsedSeconds >= 1.0 else { return Double.infinity }
        // Wall clock (mach_absolute_time on Apple Silicon) ≈ 1 ppm. Quantisation
        // error in sample-count granularity contributes 1/totalSamples ≈ 0 ppm.
        // Model the total as ≈1 ppm floor + 1/√(t) random — conservative.
        let randErr = 1.0 / elapsedSeconds.squareRoot()
        return (1.0 + randErr) * 1.0    // ≈1 ppm at 30 s
    }

    /// True once enough data has accumulated to trust `measuredPPM`.
    public var isConverged: Bool {
        elapsedSeconds >= Self.minCalibrationDuration &&
        uncertaintyPPM <= Self.convergedUncertaintyPPM
    }

    /// Multiply any nominal frequency by this factor to get the true frequency.
    /// Returns 1.0 before convergence (no correction applied).
    public var correctionFactor: Double {
        guard isConverged else { return 1.0 }
        return 1.0 + measuredPPM / 1_000_000
    }

    /// Absolute accuracy in cents that this calibration achieves.
    /// Before convergence: ±0.17 ¢ worst-case (100 ppm crystal + no correction).
    /// After convergence: ≈ uncertainty × (1/577.8) ¢.
    public var absoluteAccuracyCents: Double {
        guard isConverged else { return 100.0 / 577.8 }  // uncalibrated worst-case
        return uncertaintyPPM / 577.8
    }

    /// Reset accumulated data. Call `startMeasurement` again to restart.
    public func reset() {
        t0 = nil
        totalSamples = 0
        elapsedSeconds = 0
    }
}
