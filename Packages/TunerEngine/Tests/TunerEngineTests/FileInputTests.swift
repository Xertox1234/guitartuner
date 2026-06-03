import XCTest
@testable import TunerEngine

#if canImport(AVFoundation)
import AVFoundation

/// Exercises the **file input** path the engine supports for offline analysis
/// (and that CI can run headlessly): synthesize → write an audio file → read it
/// back via `AVAudioFile` → run the pipeline. The live `AVAudioEngine` capture
/// path can't run in CI, but this proves file/sample-buffer input works end to end.
final class FileInputTests: XCTestCase {
    let fs = 48_000.0

    func testRoundTripThroughAudioFile() throws {
        let frequency = 220.0   // A3
        let samples = Synth.harmonic(fundamental: frequency, sampleRate: fs, seconds: 0.8)

        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("tunerengine-\(UUID().uuidString).caf")
        defer { try? FileManager.default.removeItem(at: url) }

        let format = try XCTUnwrap(AVAudioFormat(
            commonFormat: .pcmFormatFloat32, sampleRate: fs, channels: 1, interleaved: false))

        // Write.
        let file = try AVAudioFile(forWriting: url, settings: format.settings)
        let writeBuffer = try XCTUnwrap(AVAudioPCMBuffer(
            pcmFormat: format, frameCapacity: AVAudioFrameCount(samples.count)))
        writeBuffer.frameLength = AVAudioFrameCount(samples.count)
        samples.withUnsafeBufferPointer { src in
            writeBuffer.floatChannelData!.pointee.update(from: src.baseAddress!, count: samples.count)
        }
        try file.write(from: writeBuffer)

        // Read back.
        let readFile = try AVAudioFile(forReading: url)
        let readFormat = readFile.processingFormat
        let frames = AVAudioFrameCount(readFile.length)
        let readBuffer = try XCTUnwrap(AVAudioPCMBuffer(pcmFormat: readFormat, frameCapacity: frames))
        try readFile.read(into: readBuffer)
        let channel = try XCTUnwrap(readBuffer.floatChannelData)
        let restored = Array(UnsafeBufferPointer(start: channel.pointee, count: Int(readBuffer.frameLength)))

        // Analyse the file content.
        let pipeline = PitchPipeline(sampleRate: readFormat.sampleRate, a4: 440, method: .mpm)
        var readings: [PitchReading] = []
        let block = 1024
        var i = 0
        while i < restored.count {
            let end = min(i + block, restored.count)
            readings += pipeline.process(Array(restored[i..<end]))
            i = end
        }

        let last = try XCTUnwrap(readings.last)
        XCTAssertEqual(last.note.description, "A3")
        XCTAssertLessThan(abs(last.cents), 5)
    }
}
#endif
