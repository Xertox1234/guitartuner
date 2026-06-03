import XCTest
@testable import TunerEngine

final class PitchDetectorTests: XCTestCase {
    let fs = 48_000.0
    let range = PitchPipeline.searchRange

    // Raw (unwindowed) frames isolate detector capability; the pipeline tests
    // cover the windowed end-to-end path.
    private func pure(_ f: Double, _ n: Int) -> [Float] {
        Array(Synth.pure(frequency: f, sampleRate: fs, seconds: Double(n) / fs + 0.01).prefix(n))
    }
    private func harmonic(_ f: Double, _ n: Int) -> [Float] {
        Array(Synth.harmonic(fundamental: f, sampleRate: fs, seconds: Double(n) / fs + 0.01).prefix(n))
    }
    private func string(_ f: Double, _ n: Int) -> [Float] {
        Array(Synth.inharmonicString(fundamental: f, sampleRate: fs, seconds: Double(n) / fs + 0.01).prefix(n))
    }
    private func err(_ r: DetectorResult?, _ truth: Double) throws -> Double {
        let r = try XCTUnwrap(r)
        return TestSupport.cents(r.frequency, truth)
    }

    func testPureToneMidRangeAllMethods() throws {
        for method in DetectionMethod.allCases {
            let r = PitchDetector.detect(pure(440, 2048), sampleRate: fs, range: range, method: method)
            XCTAssertLessThan(abs(try err(r, 440)), 2.0, "method \(method)")
            XCTAssertGreaterThan(try XCTUnwrap(r).clarity, 0.9)
        }
    }

    func testGuitarLowE() throws {
        let r = PitchDetector.detect(pure(82.41, 4096), sampleRate: fs, range: range, method: .mpm)
        XCTAssertLessThan(abs(try err(r, 82.41)), 4.0)
    }

    func testBassLowEOctaveSafe() throws {
        let r = try XCTUnwrap(PitchDetector.detect(pure(41.20, 4096), sampleRate: fs, range: range, method: .mpm))
        XCTAssertLessThan(abs(TestSupport.cents(r.frequency, 41.20)), 50, "must not jump octave")
        XCTAssertLessThan(abs(TestSupport.cents(r.frequency, 41.20)), 8.0)
    }

    func testFiveStringLowBOctaveSafe() throws {
        // B0 ≈ 30.87 Hz — the hardest case.
        let r = try XCTUnwrap(PitchDetector.detect(pure(30.87, 4096), sampleRate: fs, range: range, method: .mpm))
        XCTAssertLessThan(abs(TestSupport.cents(r.frequency, 30.87)), 50, "must not jump octave")
    }

    func testHarmonicToneTracksFundamentalNotOctave() throws {
        // A2 with 8 harmonics — fundamental is 110, not 220.
        let r = try XCTUnwrap(PitchDetector.detect(harmonic(110, 2048), sampleRate: fs, range: range, method: .mpm))
        XCTAssertEqual(r.frequency, 110, accuracy: 110 * 0.01)   // within ~17 cents, definitely not 220
        XCTAssertLessThan(abs(TestSupport.cents(r.frequency, 110)), 5.0)
    }

    func testInharmonicStringTracksFundamental() throws {
        // Stiff E2 string: partials sit sharp, but we want the fundamental.
        let r = try XCTUnwrap(PitchDetector.detect(string(82.41, 4096), sampleRate: fs, range: range, method: .mpm))
        XCTAssertLessThan(abs(TestSupport.cents(r.frequency, 82.41)), 10.0)
    }

    func testHighRangeShortWindow() throws {
        // E5 in a 1024-sample window (the "high" band geometry).
        let r = PitchDetector.detect(pure(659.26, 1024), sampleRate: fs, range: range, method: .mpm)
        XCTAssertLessThan(abs(try err(r, 659.26)), 3.0)
    }

    func testYINAndHybridAgreeOnInharmonic() throws {
        let y = try XCTUnwrap(PitchDetector.detect(string(146.83, 2048), sampleRate: fs, range: range, method: .yin))
        let h = try XCTUnwrap(PitchDetector.detect(string(146.83, 2048), sampleRate: fs, range: range, method: .hybrid))
        XCTAssertLessThan(abs(TestSupport.cents(y.frequency, 146.83)), 12.0)   // D3
        XCTAssertLessThan(abs(TestSupport.cents(h.frequency, 146.83)), 12.0)
    }

    func testSilenceReturnsNil() {
        let silence = [Float](repeating: 0, count: 2048)
        XCTAssertNil(PitchDetector.detect(silence, sampleRate: fs, range: range, method: .mpm))
    }
}
