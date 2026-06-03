import Foundation

/// Summary error statistics over a set of cents errors (estimate − truth).
public struct ErrorStats: Equatable, Sendable {
    public let count: Int
    public let mean: Double
    public let meanAbs: Double
    public let sigma: Double
    public let maxAbs: Double

    public static let empty = ErrorStats(count: 0, mean: 0, meanAbs: 0, sigma: 0, maxAbs: 0)

    /// Cents error of an estimate vs the true frequency (signal-relative, not
    /// quantised to the nearest note) — the raw accuracy number.
    public static func centsError(estimate: Double, truth: Double) -> Double {
        1200 * log2(estimate / truth)
    }

    public static func from(_ errors: [Double]) -> ErrorStats {
        guard !errors.isEmpty else { return .empty }
        let n = Double(errors.count)
        let mean = errors.reduce(0, +) / n
        let meanAbs = errors.reduce(0) { $0 + abs($1) } / n
        let variance = errors.reduce(0) { $0 + ($1 - mean) * ($1 - mean) } / n
        let maxAbs = errors.map { abs($0) }.max() ?? 0
        return ErrorStats(count: errors.count, mean: mean, meanAbs: meanAbs,
                          sigma: variance.squareRoot(), maxAbs: maxAbs)
    }
}

/// One benchmark case: a stimulus fed through a fresh pipeline, scored.
public struct CaseResult: Sendable {
    public let category: String      // signal type, e.g. "inharmonic"
    public let note: String          // e.g. "E2"
    public let trueFrequency: Double
    public let centsTarget: Double   // intended detune
    public let snrDB: Double
    public let readings: Int
    public let stats: ErrorStats     // steady-state cents error vs truth
    public let octaveError: Bool
    public let timeToLockMS: Double? // nil if never locked
    public let errors: [Double]      // steady-state cents errors (for pooling)
}

/// Runs one stimulus through a fresh pipeline and scores it. Shared by the
/// benchmark suite and the tests, so accuracy assertions and the published report
/// measure the *same* thing.
public enum CaseRunner {

    /// - lockTolerance: cents window counted as "locked" for time-to-lock.
    /// - steadyStateStart: ignore readings before this (skip the attack/acquire).
    public static func run(
        signal: [Float],
        sampleRate: Double,
        trueFrequency: Double,
        category: String,
        centsTarget: Double,
        snrDB: Double,
        method: DetectionMethod,
        a4: Double = Pitch.standardA4,
        lockTolerance: Double = 5,
        steadyStateStart: TimeInterval = 0.30
    ) -> CaseResult {
        let pipeline = PitchPipeline(sampleRate: sampleRate, a4: a4, method: method)

        // Feed in realistic ~10 ms blocks so analysis fires on true hop cadence.
        let block = max(64, Int(sampleRate * 0.01))
        var readings: [PitchReading] = []
        var i = 0
        while i < signal.count {
            let end = min(i + block, signal.count)
            readings.append(contentsOf: pipeline.process(Array(signal[i..<end])))
            i = end
        }

        // Time-to-lock: first confident reading inside the tolerance window.
        var timeToLock: Double?
        for r in readings where r.confidence >= 0.9 {
            if abs(ErrorStats.centsError(estimate: r.frequency, truth: trueFrequency)) <= lockTolerance {
                timeToLock = r.timestamp * 1000
                break
            }
        }

        // Steady-state error (ignore the acquisition transient).
        let steady = readings.filter { $0.timestamp >= steadyStateStart }
        let errors = steady.map { ErrorStats.centsError(estimate: $0.frequency, truth: trueFrequency) }
        let stats = ErrorStats.from(errors)
        // Octave error: any steady reading more than a quartertone×6 (600¢) off.
        let octaveError = errors.contains { abs($0) > 600 }

        return CaseResult(
            category: category, note: noteLabel(trueFrequency, a4: a4),
            trueFrequency: trueFrequency, centsTarget: centsTarget, snrDB: snrDB,
            readings: steady.count, stats: stats,
            octaveError: octaveError, timeToLockMS: timeToLock, errors: errors
        )
    }

    static func noteLabel(_ f: Double, a4: Double) -> String {
        Pitch.nearest(frequency: f, a4: a4).map { $0.note.description } ?? "—"
    }
}
