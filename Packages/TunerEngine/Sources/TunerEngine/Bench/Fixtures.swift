import Foundation

/// The **real-DI fixture harness** (Plan 06 §9, §12): load a small set of
/// recorded tuned-string DIs and score them through the *same* `CaseRunner` the
/// synthetic benchmark uses — so the gates measure the engine, not the
/// synthesizer the P2 estimator is fit to. Recorded audio stays **out of CI**
/// (the directory is empty by default and `run` skips gracefully); a developer
/// drops WAVs in `docs/benchmarks/fixtures/` and runs `Benchmark --fixtures …`.
///
/// Self-contained: a tiny RIFF/WAV codec (PCM 16/24/32-int + IEEE float32, mono
/// or downmixed stereo) means no AVFoundation, so it runs on the headless/Linux
/// toolchain exactly like the rest of the bench.
///
/// Filename convention encodes the truth: `"<label>_<trueHz>.wav"`
/// (e.g. `E2_82.41.wav`) or `"<note>.wav"` (e.g. `E2.wav`, frequency derived
/// from the note name via `Pitch`). Anything else is skipped with a note.
public enum Fixtures {

    public struct FixtureResult: Sendable {
        public let name: String
        public let trueFrequency: Double
        public let result: CaseResult
    }

    // MARK: - Run

    /// Load + score every parseable WAV in `directory`. Returns `[]` if the
    /// directory is missing or holds no usable fixtures (CI stays synthetic).
    public static func run(
        directory: URL,
        method: DetectionMethod = .mpm,
        a4: Double = Pitch.standardA4
    ) -> [FixtureResult] {
        let fm = FileManager.default
        guard let entries = try? fm.contentsOfDirectory(at: directory, includingPropertiesForKeys: nil) else {
            return []
        }
        var out: [FixtureResult] = []
        for url in entries.sorted(by: { $0.lastPathComponent < $1.lastPathComponent })
        where url.pathExtension.lowercased() == "wav" {
            guard let (label, hz) = parseTrueFrequency(fileName: url.lastPathComponent, a4: a4),
                  let data = try? Data(contentsOf: url),
                  let (samples, sampleRate) = decodeWAV(data), !samples.isEmpty else { continue }
            let r = CaseRunner.run(
                signal: samples, sampleRate: sampleRate, trueFrequency: hz,
                category: "fixture", centsTarget: 0, snrDB: .infinity, method: method, a4: a4,
                lockWindowStart: BenchmarkSuite.lockWindowStart)
            out.append(FixtureResult(name: label, trueFrequency: hz, result: r))
        }
        return out
    }

    // MARK: - Filename → truth

    /// `"E2_82.41.wav"` → `("E2", 82.41)`; `"E2.wav"` → `("E2", 82.41)`.
    static func parseTrueFrequency(fileName: String, a4: Double) -> (label: String, hz: Double)? {
        let stem = (fileName as NSString).deletingPathExtension
        guard !stem.isEmpty else { return nil }
        if let us = stem.lastIndex(of: "_"), let hz = Double(stem[stem.index(after: us)...]), hz > 0 {
            return (String(stem[..<us]), hz)
        }
        // Otherwise treat the whole stem as a note name (e.g. "E2", "F#3", "Bb1").
        if let hz = frequencyForNoteName(stem, a4: a4) { return (stem, hz) }
        return nil
    }

    /// `"E2"`, `"F#3"`, `"Bb1"`, `"A♯2"` → equal-tempered frequency, or `nil`.
    /// Scientific octave (A4 = MIDI 69 → octave 4), matching `Note`.
    static func frequencyForNoteName(_ name: String, a4: Double) -> Double? {
        let chars = Array(name)
        guard let base = letterSemitone(chars.first) else { return nil }
        var semitone = base, idx = 1
        while idx < chars.count, "#♯b♭".contains(chars[idx]) {
            semitone += (chars[idx] == "#" || chars[idx] == "♯") ? 1 : -1
            idx += 1
        }
        guard idx < chars.count, let octave = Int(String(chars[idx...])) else { return nil }
        return Pitch.frequency(midi: (octave + 1) * 12 + semitone, a4: a4)
    }

    private static func letterSemitone(_ c: Character?) -> Int? {
        switch c {
        case "C": return 0; case "D": return 2; case "E": return 4; case "F": return 5
        case "G": return 7; case "A": return 9; case "B": return 11; default: return nil
        }
    }

    // MARK: - Markdown

    public static func markdown(_ results: [FixtureResult]) -> String {
        guard !results.isEmpty else {
            return "\n## Real-DI fixtures\n\n_No fixtures present — drop recorded WAVs in "
                + "`docs/benchmarks/fixtures/` (named `<note>.wav` or `<label>_<trueHz>.wav`) and re-run "
                + "with `--fixtures docs/benchmarks/fixtures`. Out-of-CI by design (Plan 06 §9)._\n"
        }
        var md = "\n## Real-DI fixtures (out-of-CI regression)\n\n"
        md += "| Fixture | true Hz | abs ¢ | σ ¢ | lock σ ¢ | max ¢ | octave err |\n|---|---|---|---|---|---|---|\n"
        for r in results {
            let s = r.result
            md += "| \(r.name) | \(f2(r.trueFrequency)) | \(f2(s.stats.meanAbs)) | \(f2(s.stats.sigma)) | "
            md += "\(f2(s.lockStats.sigma)) | \(f2(s.stats.maxAbs)) | \(s.octaveError ? "⚠️ yes" : "no") |\n"
        }
        md += "\n_B-recovery on real low E/B lands with P2's harmonic estimator; P0 validates cents "
        md += "accuracy + octave safety on real strings._\n"
        return md
    }

    // MARK: - Minimal WAV codec

    /// Decode a RIFF/WAVE file: PCM 16/24/32-int or IEEE float32, mono or stereo
    /// (downmixed). Returns mono `[Float]` in −1…1 and the sample rate, or `nil`.
    public static func decodeWAV(_ data: Data) -> (samples: [Float], sampleRate: Double)? {
        let b = [UInt8](data)
        guard b.count >= 44, tag(b, 0) == "RIFF", tag(b, 8) == "WAVE" else { return nil }

        var channels = 0, bits = 0, format = 0
        var sampleRate = 0.0
        var dataStart = -1, dataSize = 0

        var pos = 12
        while pos + 8 <= b.count {
            let id = tag(b, pos)
            let size = Int(u32(b, pos + 4))
            let body = pos + 8
            if id == "fmt " && body + 16 <= b.count {
                format = Int(u16(b, body))
                channels = Int(u16(b, body + 2))
                sampleRate = Double(u32(b, body + 4))
                bits = Int(u16(b, body + 14))
                if format == 0xFFFE, body + 26 <= b.count { format = Int(u16(b, body + 24)) } // extensible → subformat
            } else if id == "data" {
                dataStart = body
                dataSize = min(size, b.count - body)
            }
            pos = body + size + (size & 1) // chunks are word-aligned
        }

        guard channels > 0, sampleRate > 0, dataStart >= 0, (format == 1 || format == 3) else { return nil }
        let bytes = bits / 8
        guard bytes > 0 else { return nil }
        let frames = dataSize / (bytes * channels)
        guard frames > 0 else { return nil }

        var out = [Float](repeating: 0, count: frames)
        for i in 0..<frames {
            var acc: Float = 0
            for c in 0..<channels {
                acc += sample(b, dataStart + (i * channels + c) * bytes, bits: bits, float: format == 3)
            }
            out[i] = acc / Float(channels)
        }
        return (out, sampleRate)
    }

    /// Encode mono `[Float]` (−1…1) as a 16-bit PCM WAV — handy for building
    /// fixtures and for round-trip tests without committing binary audio.
    public static func encodeWAV(_ samples: [Float], sampleRate: Double) -> Data {
        var d = Data()
        func a32(_ v: UInt32) { d.append(contentsOf: [UInt8(v & 0xFF), UInt8((v >> 8) & 0xFF), UInt8((v >> 16) & 0xFF), UInt8((v >> 24) & 0xFF)]) }
        func a16(_ v: UInt16) { d.append(contentsOf: [UInt8(v & 0xFF), UInt8((v >> 8) & 0xFF)]) }
        func ascii(_ s: String) { d.append(contentsOf: Array(s.utf8)) }
        let dataBytes = UInt32(samples.count * 2)
        ascii("RIFF"); a32(36 + dataBytes); ascii("WAVE")
        ascii("fmt "); a32(16); a16(1); a16(1); a32(UInt32(sampleRate))
        a32(UInt32(sampleRate) * 2); a16(2); a16(16)            // byteRate, blockAlign, bits
        ascii("data"); a32(dataBytes)
        for s in samples {
            let v = Int16(max(-1, min(1, s)) * 32767)
            a16(UInt16(bitPattern: v))
        }
        return d
    }

    // MARK: - byte helpers

    private static func tag(_ b: [UInt8], _ o: Int) -> String {
        guard o + 4 <= b.count else { return "" }
        return String(bytes: b[o..<o + 4], encoding: .ascii) ?? ""
    }
    private static func u32(_ b: [UInt8], _ o: Int) -> UInt32 {
        UInt32(b[o]) | UInt32(b[o + 1]) << 8 | UInt32(b[o + 2]) << 16 | UInt32(b[o + 3]) << 24
    }
    private static func u16(_ b: [UInt8], _ o: Int) -> UInt16 { UInt16(b[o]) | UInt16(b[o + 1]) << 8 }

    /// One sample at byte offset `o` as Float in −1…1.
    private static func sample(_ b: [UInt8], _ o: Int, bits: Int, float: Bool) -> Float {
        switch (float, bits) {
        case (true, 32):
            return Float(bitPattern: u32(b, o))
        case (false, 16):
            return Float(Int16(bitPattern: u16(b, o))) / 32768
        case (false, 24):
            let raw = Int32(b[o]) | Int32(b[o + 1]) << 8 | Int32(b[o + 2]) << 16
            let signed = (raw & 0x80_0000) != 0 ? raw - 0x100_0000 : raw
            return Float(signed) / 8_388_608
        case (false, 32):
            return Float(Int32(bitPattern: u32(b, o))) / 2_147_483_648
        default:
            return 0
        }
    }

    private static func f2(_ x: Double) -> String { String(format: "%.2f", x) }
}
