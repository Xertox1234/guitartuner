import XCTest
@testable import TunerEngine

final class PipelineTests: XCTestCase {
    let fs = 48_000.0

    /// Feed a full signal through a fresh pipeline in 10 ms blocks.
    private func run(_ signal: [Float], a4: Double = 440, method: DetectionMethod = .mpm,
                     targetNote: Note? = nil) -> [PitchReading] {
        let p = PitchPipeline(sampleRate: fs, a4: a4, method: method, targetNote: targetNote)
        let block = 480
        var out: [PitchReading] = []
        var i = 0
        while i < signal.count {
            let end = min(i + block, signal.count)
            out += p.process(Array(signal[i..<end]))
            i = end
        }
        return out
    }

    private func steady(_ rs: [PitchReading], after t: TimeInterval = 0.4) -> [PitchReading] {
        rs.filter { $0.timestamp >= t }
    }
    private func sigma(_ xs: [Double]) -> Double {
        guard xs.count > 1 else { return 0 }
        let m = xs.reduce(0, +) / Double(xs.count)
        return (xs.reduce(0) { $0 + ($1 - m) * ($1 - m) } / Double(xs.count)).squareRoot()
    }

    func testTracksCleanGuitarNote() throws {
        // G3 = 196 Hz.
        let rs = run(Synth.harmonic(fundamental: 196, sampleRate: fs, seconds: 0.8))
        let last = try XCTUnwrap(rs.last)
        XCTAssertEqual(last.note.description, "G3")
        XCTAssertLessThan(abs(last.cents), 3.0)
        XCTAssertGreaterThan(last.confidence, 0.8)
    }

    func testSteadyToneIsLowJitter() {
        let rs = steady(run(Synth.pure(frequency: 246.94, sampleRate: fs, seconds: 0.9)))  // B3
        XCTAssertGreaterThan(rs.count, 5)
        XCTAssertLessThan(sigma(rs.map(\.cents)), 3.0, "steady tone should barely jitter")
    }

    func testDetunedReadsCorrectCents() throws {
        let f = 110 * pow(2, 20.0 / 1200)        // A2, +20¢
        let rs = steady(run(Synth.harmonic(fundamental: f, sampleRate: fs, seconds: 0.9)))
        let mean = rs.map(\.cents).reduce(0, +) / Double(max(1, rs.count))
        XCTAssertEqual(mean, 20, accuracy: 5)
        XCTAssertEqual(try XCTUnwrap(rs.last).note.description, "A2")
    }

    func testInharmonicGuitarString() throws {
        let rs = steady(run(Synth.inharmonicString(fundamental: 82.41, sampleRate: fs, seconds: 1.0)))
        let last = try XCTUnwrap(rs.last)
        XCTAssertEqual(last.note.description, "E2")
        XCTAssertLessThan(abs(last.cents), 12)
    }

    func testLowBassOctaveSafety() throws {
        // E1 = 41.2 Hz — must read E1, never E2.
        let rs = steady(run(Synth.inharmonicString(fundamental: 41.20, sampleRate: fs, seconds: 1.3)), after: 0.5)
        let last = try XCTUnwrap(rs.last)
        XCTAssertEqual(last.note.octave, 1, "octave-safe on low bass")
        XCTAssertEqual(last.note.name, "E")
    }

    func testNoiseRobustness() throws {
        var rng = SeededRNG(seed: 99)
        let clean = Synth.inharmonicString(fundamental: 220, sampleRate: fs, seconds: 0.9)  // A3
        let noisy = Synth.addNoise(to: clean, snrDB: 20, rng: &rng)
        let rs = steady(run(noisy))
        XCTAssertGreaterThan(rs.count, 3)
        // No octave errors, and the settled reading stays close.
        XCTAssertTrue(rs.allSatisfy { abs(TestSupport.cents($0.frequency, 220)) < 50 }, "no octave error under noise")
        XCTAssertLessThan(abs(TestSupport.cents(try XCTUnwrap(rs.last).frequency, 220)), 20)
    }

    func testPhaseAlwaysNormalized() {
        let rs = run(Synth.pure(frequency: 329.63, sampleRate: fs, seconds: 0.6))  // E4
        XCTAssertFalse(rs.isEmpty)
        for r in rs {
            XCTAssertGreaterThanOrEqual(r.phase, 0)
            XCTAssertLessThan(r.phase, 1)
        }
    }

    func testSilenceProducesNoReadings() {
        let rs = run([Float](repeating: 0, count: Int(fs * 0.5)))
        XCTAssertTrue(rs.isEmpty)
    }

    func testOctaveGuardAllowsCleanJump() throws {
        // A2 (110 Hz) then A3 (220 Hz): clean signal has clarity ≥ 0.95, guard must not block.
        let a2 = Synth.harmonic(fundamental: 110, sampleRate: fs, seconds: 0.7)
        let a3 = Synth.harmonic(fundamental: 220, sampleRate: fs, seconds: 0.7)
        let rs = run(a2 + a3)
        let late = rs.filter { $0.timestamp > 1.0 }
        XCTAssertTrue(late.contains { $0.note.description == "A3" },
                      "clean octave jump should pass the octave guard")
    }

    func testOctaveGuardSuppressesLowClarityOctaveJump() {
        // A2 tracked, then a noisy 220 Hz burst (SNR ≈ 8 dB → clarity < 0.95).
        // The octave guard should suppress readings during the ambiguous burst.
        var rng = SeededRNG(seed: 7)
        let a2 = Synth.harmonic(fundamental: 110, sampleRate: fs, seconds: 0.7)
        let noisyDouble = Synth.addNoise(
            to: Synth.pure(frequency: 220, sampleRate: fs, seconds: 0.25),
            snrDB: 8, rng: &rng
        )
        let rs = run(a2 + noisyDouble)
        let duringBurst = rs.filter { $0.timestamp >= 0.7 }
        XCTAssertFalse(duringBurst.contains { $0.note.description == "A3" },
                       "low-clarity octave jump should be suppressed by the octave guard")
    }

    func testA4Calibration() throws {
        // At A4 = 432, a 432 Hz tone is A4 ± ~0¢.
        let rs = steady(run(Synth.pure(frequency: 432, sampleRate: fs, seconds: 0.7), a4: 432))
        let last = try XCTUnwrap(rs.last)
        XCTAssertEqual(last.note.description, "A4")
        XCTAssertLessThan(abs(last.cents), 3)
    }
}
