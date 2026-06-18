import Foundation
import Testing
@testable import TunerEngine

@Suite struct PitchDetectorTests {
    let fs = 48_000.0
    let range = PitchPipeline.searchRange

    private func pure(_ f: Double, _ n: Int) -> [Float] {
        Array(Synth.pure(frequency: f, sampleRate: fs, seconds: Double(n) / fs + 0.01).prefix(n))
    }
    private func harmonic(_ f: Double, _ n: Int) -> [Float] {
        Array(Synth.harmonic(fundamental: f, sampleRate: fs, seconds: Double(n) / fs + 0.01).prefix(n))
    }
    private func string(_ f: Double, _ n: Int) -> [Float] {
        Array(Synth.inharmonicString(fundamental: f, sampleRate: fs, seconds: Double(n) / fs + 0.01).prefix(n))
    }

    @Test(arguments: DetectionMethod.allCases)
    func pureToneMidRangeAllMethods(_ method: DetectionMethod) throws {
        let r = try #require(PitchDetector.detect(pure(440, 2048), sampleRate: fs, range: range, method: method))
        #expect(abs(TestSupport.cents(r.frequency, 440)) < 2.0)
        #expect(r.clarity > 0.9)
    }

    // Parameterized octave-safety for all low bass strings in a single test.
    // maxCents: E2 ≤ 4¢, E1 ≤ 8¢, B0 ≤ 50¢ (octave-safe only — hardest case).
    @Test(arguments: [82.41, 41.20, 30.87])
    func lowNoteIsOctaveSafe(_ f: Double) throws {
        let r = try #require(PitchDetector.detect(pure(f, 4096), sampleRate: fs, range: range, method: .mpm))
        let maxCents: Double = f > 60 ? 4.0 : (f > 35 ? 8.0 : 50.0)
        #expect(abs(TestSupport.cents(r.frequency, f)) < 50, "octave error at f=\(f) Hz")
        #expect(abs(TestSupport.cents(r.frequency, f)) < maxCents)
    }

    @Test func harmonicToneTracksFundamental() throws {
        // A2 with 8 harmonics — fundamental is 110, not 220.
        let r = try #require(PitchDetector.detect(harmonic(110, 2048), sampleRate: fs, range: range, method: .mpm))
        #expect(abs(TestSupport.cents(r.frequency, 110)) < 5.0)
    }

    @Test func inharmonicStringTracksFundamental() throws {
        // Stiff E2 string: partials sit sharp, but we want the fundamental.
        let r = try #require(PitchDetector.detect(string(82.41, 4096), sampleRate: fs, range: range, method: .mpm))
        #expect(abs(TestSupport.cents(r.frequency, 82.41)) < 10.0)
    }

    @Test func highRangeShortWindow() throws {
        // E5 in a 1024-sample window (the "high" band geometry).
        let r = try #require(PitchDetector.detect(pure(659.26, 1024), sampleRate: fs, range: range, method: .mpm))
        #expect(abs(TestSupport.cents(r.frequency, 659.26)) < 3.0)
    }

    @Test func yinAndHybridAgreeOnInharmonic() throws {
        let y = try #require(PitchDetector.detect(string(146.83, 2048), sampleRate: fs, range: range, method: .yin))
        let h = try #require(PitchDetector.detect(string(146.83, 2048), sampleRate: fs, range: range, method: .hybrid))
        #expect(abs(TestSupport.cents(y.frequency, 146.83)) < 12.0)
        #expect(abs(TestSupport.cents(h.frequency, 146.83)) < 12.0)
    }

    @Test func silenceReturnsNil() {
        #expect(PitchDetector.detect([Float](repeating: 0, count: 2048), sampleRate: fs, range: range, method: .mpm) == nil)
    }

    // Contract test: an explicit emitFloor equal to the default produces the same
    // result as omitting it — i.e. the parameter exists, defaults to the legacy
    // constant, and is backward-compatible. This does NOT prove the value is routed
    // into the octave-rescue pick (both calls use 0.5, so determinism alone passes
    // it). True routing coverage arrives when the deferred bass-fix first exercises
    // a non-default floor (docs/todos/P1-bass-detection-policy-tuning.md).
    @Test func detectAcceptsEmitFloorAndDefaultsToLegacy() {
        let frame = TestSupport.stringFrame(110, n: 4096)
        let a = PitchDetector.detect(frame, sampleRate: TestSupport.fs,
                                     range: 27...1400, method: .hybrid)
        let b = PitchDetector.detect(frame, sampleRate: TestSupport.fs,
                                     range: 27...1400, method: .hybrid, emitFloor: 0.5)
        #expect(a?.frequency == b?.frequency, "explicit default floor matches implicit default")
        #expect((b?.frequency ?? 0) > 0)
    }
}
