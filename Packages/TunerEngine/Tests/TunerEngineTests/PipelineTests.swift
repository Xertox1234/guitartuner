import Foundation
import Testing
@testable import TunerEngine

@Suite struct PipelineTests {
    let fs = 48_000.0

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

    @Test func tracksCleanGuitarNote() throws {
        let rs = run(Synth.harmonic(fundamental: 196, sampleRate: fs, seconds: 0.8))
        let last = try #require(rs.last)
        #expect(last.note.description == "G3")
        #expect(abs(last.cents) < 1.0)
        #expect(last.confidence > 0.8)
    }

    @Test func steadyToneIsLowJitter() {
        let rs = steady(run(Synth.pure(frequency: 246.94, sampleRate: fs, seconds: 0.9)))
        #expect(rs.count > 5)
        #expect(sigma(rs.map(\.cents)) < 1.0, "steady pure tone should barely jitter")
    }

    @Test func detunedReadsCorrectCents() throws {
        let f = 110 * pow(2, 20.0 / 1200)        // A2, +20¢
        let rs = steady(run(Synth.harmonic(fundamental: f, sampleRate: fs, seconds: 0.9)))
        let mean = rs.map(\.cents).reduce(0, +) / Double(max(1, rs.count))
        #expect(abs(mean - 20) < 2, "detuned A2 mean should read +20¢")
        let last = try #require(rs.last)
        #expect(last.note.description == "A2")
    }

    @Test func inharmonicGuitarString() throws {
        let rs = steady(run(Synth.inharmonicString(fundamental: 82.41, sampleRate: fs, seconds: 1.0)))
        let last = try #require(rs.last)
        #expect(last.note.description == "E2")
        #expect(abs(last.cents) < 3.0)
    }

    @Test func lowBassOctaveSafety() throws {
        // E1 = 41.2 Hz — must read E1, never E2.
        let rs = steady(run(Synth.inharmonicString(fundamental: 41.20, sampleRate: fs, seconds: 1.3)), after: 0.5)
        let last = try #require(rs.last)
        #expect(last.note.octave == 1, "octave-safe on low bass")
        #expect(last.note.name == "E")
    }

    // M16: Low-string octave safety under weak fundamental, exercised in the fast
    // swift test cycle. The benchmark covers only clean tones; stress stimuli
    // (weak/missing fund.) are normally only in --ci runs. This parameterized test
    // catches regressions on the hardest strings in < 10 s.
    @Test(arguments: [30.87, 41.20])   // B0, E1
    func lowBassOctaveSafeUnderWeakFundamental(_ f: Double) {
        let signal = Synth.inharmonicString(fundamental: f, sampleRate: fs, seconds: 1.5,
                                            fundamentalLevel: 0.15)
        let result = CaseRunner.run(
            signal: signal, sampleRate: fs, trueFrequency: f,
            category: "weak-fund", centsTarget: 0, snrDB: 60, method: .mpm
        )
        #expect(!result.octaveError, "octave error on f=\(f) Hz with weak fundamental")
        #expect(result.readings > 3, "pipeline should produce steady readings at f=\(f) Hz")
    }

    @Test func noiseRobustness() throws {
        var rng = SeededRNG(seed: 99)
        let clean = Synth.inharmonicString(fundamental: 220, sampleRate: fs, seconds: 0.9)
        let noisy = Synth.addNoise(to: clean, snrDB: 20, rng: &rng)
        let rs = steady(run(noisy))
        #expect(rs.count > 3)
        #expect(rs.allSatisfy { abs(TestSupport.cents($0.frequency, 220)) < 50 }, "no octave error under noise")
        let last = try #require(rs.last)
        #expect(abs(TestSupport.cents(last.frequency, 220)) < 5.0)
    }

    @Test func phaseAlwaysNormalized() {
        let rs = run(Synth.pure(frequency: 329.63, sampleRate: fs, seconds: 0.6))
        #expect(!rs.isEmpty)
        for r in rs {
            #expect(r.phase >= 0)
            #expect(r.phase < 1)
        }
    }

    @Test func silenceProducesNoReadings() {
        let rs = run([Float](repeating: 0, count: Int(fs * 0.5)))
        #expect(rs.isEmpty)
    }

    @Test func octaveGuardAllowsCleanJump() throws {
        // A2 (110 Hz) then A3 (220 Hz): clean signal has clarity ≥ 0.95, guard must not block.
        let a2 = Synth.harmonic(fundamental: 110, sampleRate: fs, seconds: 0.7)
        let a3 = Synth.harmonic(fundamental: 220, sampleRate: fs, seconds: 0.7)
        let rs = run(a2 + a3)
        let late = rs.filter { $0.timestamp > 1.0 }
        #expect(late.contains { $0.note.description == "A3" },
                "clean octave jump should pass the octave guard")
    }

    @Test func octaveGuardSuppressesLowClarityOctaveJump() {
        // A2 tracked, then a noisy 220 Hz burst (SNR ≈ 8 dB → clarity < 0.95).
        var rng = SeededRNG(seed: 7)
        let a2 = Synth.harmonic(fundamental: 110, sampleRate: fs, seconds: 0.7)
        let noisyDouble = Synth.addNoise(
            to: Synth.pure(frequency: 220, sampleRate: fs, seconds: 0.25),
            snrDB: 8, rng: &rng
        )
        let rs = run(a2 + noisyDouble)
        let duringBurst = rs.filter { $0.timestamp >= 0.7 }
        #expect(!duringBurst.contains { $0.note.description == "A3" },
                "low-clarity octave jump should be suppressed by the octave guard")
    }

    @Test func a4Calibration() throws {
        // At A4 = 432, a 432 Hz tone is A4 ± ~0¢.
        let rs = steady(run(Synth.pure(frequency: 432, sampleRate: fs, seconds: 0.7), a4: 432))
        let last = try #require(rs.last)
        #expect(last.note.description == "A4")
        #expect(abs(last.cents) < 1.0)
    }

    @Test func nextBandReproducesLegacyTransitionsOnSweep() {
        let p = DetectionPolicy.fullRange
        func label(_ f0: Double, from: String) -> String {
            let cur = (p.bands.first { $0.label == from }) ?? p.acquire
            return PitchPipeline.nextBand(for: f0, current: cur, in: p).label
        }
        // Rising edges (band-above floor + hysteresis): 45 / 130 / 265.
        #expect(label(46, from: "ultralow") == "low")
        #expect(label(131, from: "low") == "mid")
        #expect(label(266, from: "mid") == "high")
        // Falling edges (current floor − hysteresis): 235 / 110 / 35.
        #expect(label(234, from: "high") == "mid")
        #expect(label(109, from: "mid") == "low")
        #expect(label(34, from: "low") == "ultralow")
        // Inside hysteresis → stays put (no chatter).
        #expect(label(250, from: "mid") == "mid")
        #expect(label(40, from: "low") == "low")
    }

    @Test func customBandPlanChangesChosenWindow() {
        // A one-band policy with a huge window proves the plumbing is live.
        let band = BandSpec(window: 16384, hop: 4096, floorHz: 0, hysteresisHz: 0,
                            sustainConfidence: 0.6, lockConfidence: 0.75, label: "only")
        let custom = DetectionPolicy(searchRange: 27...1400, bands: [band], acquire: band,
                                     smoothingAlpha: 0.35, smoothingMedianCount: 5, emitFloor: 0.5)
        #expect(PitchPipeline.nextBand(for: 200, current: band, in: custom).window == 16384)
    }
}
