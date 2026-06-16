import XCTest
@testable import TunerEngine

/// Exercises the real-DI fixture harness end-to-end without committing binary
/// audio: synthesize → encode WAV → decode → score, plus the filename parser and
/// the graceful no-fixtures skip (Plan 06 §9).
final class FixturesTests: XCTestCase {
    let fs = 48_000.0

    // MARK: filename → truth

    func testParseTrueFrequency() {
        // Explicit Hz wins.
        XCTAssertEqual(Fixtures.parseTrueFrequency(fileName: "E2_82.41.wav", a4: 440)?.hz ?? 0, 82.41, accuracy: 1e-9)
        XCTAssertEqual(Fixtures.parseTrueFrequency(fileName: "lowB_30.87.wav", a4: 440)?.label, "lowB")
        // Note-name derivation matches Pitch/Note.
        XCTAssertEqual(Fixtures.parseTrueFrequency(fileName: "E2.wav", a4: 440)?.hz ?? 0,
                       Pitch.frequency(midi: 40), accuracy: 1e-9)
        XCTAssertEqual(Fixtures.parseTrueFrequency(fileName: "A4.wav", a4: 440)?.hz ?? 0, 440, accuracy: 1e-9)
        XCTAssertEqual(Fixtures.parseTrueFrequency(fileName: "Bb1.wav", a4: 440)?.hz ?? 0,
                       Pitch.frequency(midi: 34), accuracy: 1e-9)   // Bb1 == A#1
        XCTAssertNil(Fixtures.parseTrueFrequency(fileName: "garbage.wav", a4: 440))
    }

    // MARK: WAV round-trip

    func testWavRoundTrip() {
        let tone = Synth.pure(frequency: 220, sampleRate: fs, seconds: 0.2, amplitude: 0.8)
        let wav = Fixtures.encodeWAV(tone, sampleRate: fs)
        guard let (decoded, sr) = Fixtures.decodeWAV(wav) else { return XCTFail("decode failed") }
        XCTAssertEqual(sr, fs, accuracy: 1e-9)
        XCTAssertEqual(decoded.count, tone.count)
        // 16-bit quantisation error only (~1/32768).
        var maxErr: Float = 0
        for (a, b) in zip(tone, decoded) { maxErr = max(maxErr, abs(a - b)) }
        XCTAssertLessThan(maxErr, 1e-3)
        XCTAssertNil(Fixtures.decodeWAV(Data([0, 1, 2, 3])))   // garbage → nil
    }

    // MARK: end-to-end scoring from a directory

    func testRunScoresFixturesFromDirectory() throws {
        let dir = FileManager.default.temporaryDirectory.appendingPathComponent("luma-fixtures-\(ProcessInfo.processInfo.processIdentifier)")
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: dir) }

        // Synthesize each at the frequency its filename declares (explicit Hz, or
        // the note name "A2" → 110 Hz via the parser) so truth and signal agree.
        for (file, hz) in [("E2_82.41.wav", 82.41), ("A2.wav", 110.0)] {
            let tone = Synth.inharmonicString(fundamental: hz, sampleRate: fs, seconds: 1.4)
            try Fixtures.encodeWAV(tone, sampleRate: fs).write(to: dir.appendingPathComponent(file))
        }

        let results = Fixtures.run(directory: dir, method: .mpm)
        XCTAssertEqual(results.count, 2)
        for r in results {
            XCTAssertFalse(r.result.octaveError, "\(r.name) octave-safe")
            XCTAssertLessThan(r.result.stats.meanAbs, 5, "\(r.name) accuracy")
        }
        // Markdown renders a table when fixtures exist.
        XCTAssertTrue(Fixtures.markdown(results).contains("Real-DI fixtures"))
    }

    // MARK: graceful skip (keeps CI synthetic)

    func testMissingDirectoryYieldsNoFixtures() {
        let missing = URL(fileURLWithPath: "/nonexistent/luma/fixtures/path")
        XCTAssertTrue(Fixtures.run(directory: missing).isEmpty)
        XCTAssertTrue(Fixtures.markdown([]).contains("No fixtures present"))
    }
}
