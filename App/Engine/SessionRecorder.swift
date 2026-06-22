import Foundation
import TunerEngine

#if DEBUG
/// Session context written into the CSV header — all known at record time.
struct SessionMetadata {
    var instrument: String
    var tuningId: String
    var a4: Double
    var correctionFactor: Double
    var sampleRate: Double
    var deviceModel: String
    var referenceNote: String
    var capturedAt: Date
    var appVersion: String
}

/// DEBUG-only recorder: accumulates the exact mono samples the pipeline consumed plus
/// the raw per-hop readings, and on stop writes a `Fixtures`-compatible Float32 WAV +
/// a readings CSV. Platform-agnostic (no UIKit) so the core unit-tests on macOS; the
/// iOS share-sheet export lives in the view layer. Spec §4/§5.
@MainActor
final class SessionRecorder {
    private(set) var samples: [Float] = []
    private(set) var readings: [PitchReading] = []
    private(set) var peak: Float = 0
    private(set) var clippedCount = 0
    private(set) var capReached = false

    let sampleRate: Double
    let maxSamples: Int          // ~5 min soft cap

    init(sampleRate: Double, maxSeconds: Double = 300) {
        self.sampleRate = sampleRate
        self.maxSamples = Int(sampleRate * maxSeconds)
    }

    /// Append one captured block; updates peak/clip; trips the cap (the caller stops
    /// the engine yield when `capReached`). No-op once capped.
    func append(samples block: [Float]) {
        guard !capReached else { return }
        for s in block {
            let a = abs(s)
            if a > peak { peak = a }
            if a >= 1.0 { clippedCount += 1 }
        }
        let room = maxSamples - samples.count
        if block.count >= room {
            samples.append(contentsOf: block.prefix(room))
            capReached = true
        } else {
            samples.append(contentsOf: block)
        }
    }

    func append(reading: PitchReading) {
        guard !capReached else { return }
        readings.append(reading)
    }

    // MARK: Pure builders (unit-tested)

    func wavData() -> Data { Fixtures.encodeWAVFloat32(samples, sampleRate: sampleRate) }

    /// `#`-commented metadata header + one **raw** reading row per hop.
    func csv(metadata m: SessionMetadata) -> String {
        var out = ""
        out += "# instrument,\(m.instrument)\n"
        out += "# tuningId,\(m.tuningId)\n"
        out += "# a4,\(m.a4)\n"
        out += "# correctionFactor,\(m.correctionFactor)\n"
        out += "# sampleRate,\(m.sampleRate)\n"
        out += "# deviceModel,\(m.deviceModel)\n"
        out += "# referenceNote,\(m.referenceNote)\n"
        out += "# capturedAt,\(ISO8601DateFormatter().string(from: m.capturedAt))\n"
        out += "# appVersion,\(m.appVersion)\n"
        out += "timestamp,frequency,note,cents,confidence,phase,inharmonicityB,precisionCents,isLockIntegrated\n"
        for r in readings {
            let b = r.inharmonicityB.map { String($0) } ?? ""
            let p = r.precisionCents.map { String($0) } ?? ""
            out += "\(r.timestamp),\(r.frequency),\(r.note.name)\(r.note.octave),\(r.cents),\(r.confidence),\(r.phase),\(b),\(p),\(r.isLockIntegrated)\n"
        }
        return out
    }

    /// Derive a `Fixtures`-parseable stem (no extension). An explicit `override` wins
    /// (validated). Else lock mode pre-fills `<note><octave>_<nominalHz>` from the
    /// target; auto/chromatic (no target) returns nil — true Hz is undefined there.
    static func fixtureStem(targetNote: Note?, a4: Double, override: String?) -> String? {
        if let o = override, !o.isEmpty {
            return Fixtures.parseTrueFrequency(fileName: o + ".wav", a4: a4) != nil ? o : nil
        }
        guard let t = targetNote else { return nil }
        let stem = "\(t.name)\(t.octave)_\(String(format: "%.2f", t.frequency(a4: a4)))"
        return Fixtures.parseTrueFrequency(fileName: stem + ".wav", a4: a4) != nil ? stem : nil
    }

    // MARK: I/O

    /// Write `<stem>.wav` + `<stem>.csv` into `directory`; returns the two URLs.
    func write(stem: String, metadata: SessionMetadata, to directory: URL) throws -> (wav: URL, csv: URL) {
        let wavURL = directory.appendingPathComponent(stem + ".wav")
        let csvURL = directory.appendingPathComponent(stem + ".csv")
        try wavData().write(to: wavURL)
        try Data(csv(metadata: metadata).utf8).write(to: csvURL)
        return (wavURL, csvURL)
    }
}
#endif
