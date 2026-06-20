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

    @Test func weakFundE1SettlesUnderBassPolicy() {
        let f = 41.20   // E1, the canonical bass settle stressor
        let sig = Synth.inharmonicString(fundamental: f, sampleRate: fs, seconds: 2.6, fundamentalLevel: 0.15)
        let p = PitchPipeline(sampleRate: fs, a4: 440, method: .mpm, policy: .bass)
        let block = 480
        var rs: [PitchReading] = []
        var i = 0
        while i < sig.count { let e = min(i + block, sig.count); rs += p.process(Array(sig[i..<e])); i = e }

        let window = rs.filter { $0.timestamp >= 1.0 }
        #expect(window.count > 5, "must produce a held-note window")
        let retention = Double(window.filter { $0.isLockIntegrated }.count) / Double(window.count)
        #expect(retention >= 0.85, "E1 weak-fund should hold DSP lock through the sustain")
        #expect(sigma(window.map(\.cents)) < 0.30, "held-note jitter must be strobe-grade")
        // Octave-safety must never regress while tuning.
        #expect(window.allSatisfy { abs(TestSupport.cents($0.frequency, f)) < 600 }, "no octave slip on E1")
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

    /// Pins the ONE place `nextBand` intentionally diverges from the legacy
    /// `nextConfig`: from `mid`, a fundamental below 40 Hz now settles to
    /// `ultralow` (8192 window) where the old switch returned `low` (4096) for any
    /// f0 < 110. Unreachable on guitar (60 Hz search floor) and unbenchmarked
    /// (steady tones never sweep mid→sub-40), so Slice 1's zero-delta proof holds.
    /// Reachable on bass (searchRange 25…420); the deferred bass-fix rewrites this
    /// transition — if it changes, update this expectation deliberately.
    /// (docs/todos/P1-bass-detection-policy-tuning.md, FU-1.)
    @Test func nextBandFromMidBelow40SettlesToUltralow() {
        let p = DetectionPolicy.fullRange
        let mid = (p.bands.first { $0.label == "mid" }) ?? p.acquire
        #expect(PitchPipeline.nextBand(for: 30, current: mid, in: p).label == "ultralow")
    }

    @Test func customBandPlanChangesChosenWindow() {
        // Two custom bands with distinct windows: nextBand must pick the band (and
        // thus the window/hop) from the *custom* policy's geometry, not hardcoded
        // constants — proving the policy drives band selection. (Full window→analysis
        // integration is covered by the .fullRange pipeline tests at various pitches.)
        let lo = BandSpec(window: 16384, hop: 4096, floorHz: 0,   hysteresisHz: 0,
                          sustainConfidence: 0.6, lockConfidence: 0.75, label: "lo")
        let hi = BandSpec(window: 2048,  hop: 512,  floorHz: 100, hysteresisHz: 5,
                          sustainConfidence: 0.6, lockConfidence: 0.75, label: "hi")
        let custom = DetectionPolicy(searchRange: 27...1400, bands: [hi, lo], acquire: lo,
                                     smoothingAlpha: 0.35, smoothingMedianCount: 5, emitFloor: 0.5)
        // From lo, an f0 above hi's floor+hysteresis (>=105) rises to hi (window 2048).
        #expect(PitchPipeline.nextBand(for: 200, current: lo, in: custom).window == 2048)
        // From hi, an f0 below hi's floor-hysteresis (<95) drops to lo (window 16384).
        #expect(PitchPipeline.nextBand(for: 50, current: hi, in: custom).window == 16384)
    }

    @Test(arguments: [65.41, 82.41, 110.0, 196.0, 329.63])   // C2 (Drop C) … E4
    func guitarClampMatchesFullRangeOnGuitarNotes(_ f: Double) throws {
        func lastNote(_ policy: DetectionPolicy) throws -> (String, Double) {
            let p = PitchPipeline(sampleRate: fs, a4: 440, method: .mpm, policy: policy)
            let sig = Synth.inharmonicString(fundamental: f, sampleRate: fs, seconds: 1.0)
            let block = 480
            var rs: [PitchReading] = []
            var i = 0
            while i < sig.count { let e = min(i + block, sig.count); rs += p.process(Array(sig[i..<e])); i = e }
            let last = try #require(rs.last)
            return (last.note.description, last.cents)
        }
        let full = try lastNote(.fullRange)
        let guitar = try lastNote(.guitar)
        #expect(full.0 == guitar.0, "note identical under clamp at \(f) Hz")
        #expect(abs(full.1 - guitar.1) < 0.01, "cents identical under clamp at \(f) Hz")
    }

    // MARK: - setPolicy state reset (docs/todos/P2-setpolicy-state-reset-test.md)

    /// `setPolicy` is the load-bearing seam of live instrument switching: a mid-stream
    /// swap must **reset detection state** so the previous instrument's lock/track/gate
    /// does not bleed into the new one. This pins the *reset* per field (not mere policy
    /// propagation) plus the behavioural cold re-acquire. Each per-field `#expect` fails
    /// if its matching reset line is dropped from `setPolicy` — verified by removing the
    /// reset lines one at a time (the behavioural `isLockIntegrated` check alone only
    /// catches `gate.reset()` + `phaseIntegrator.reset()` removed *together*).
    @Test func setPolicyResetsDetectionStateForColdReacquire() throws {
        let f = 196.0   // G3 — tracked under both .guitar (60…1400) and .bass (25…420)
        let block = 480
        let p = PitchPipeline(sampleRate: fs, a4: 440, method: .mpm, policy: .guitar)

        func feed(_ seconds: Double) -> [PitchReading] {
            let sig = Synth.harmonic(fundamental: f, sampleRate: fs, seconds: seconds)
            var rs: [PitchReading] = []
            var i = 0
            while i < sig.count { let e = min(i + block, sig.count); rs += p.process(Array(sig[i..<e])); i = e }
            return rs
        }

        // 1) Warm the pipeline under .guitar so every reset target is populated —
        //    otherwise the post-swap "is cold" assertions would be vacuous.
        let preSwap = feed(1.2)
        #expect(preSwap.contains { $0.isLockIntegrated },
                "precondition: must reach an integrated lock before the swap")
        let warm = p.stateProbe
        #expect(warm.trackedFrequency != nil, "precondition: tracked frequency warm")
        #expect(!warm.gateIsCold, "precondition: sustain gate warm")
        #expect(!warm.smootherIsCold, "precondition: smoother warm")
        #expect(!warm.integratorIsCold, "precondition: phase integrator warm")
        #expect(warm.hasPrevFrame, "precondition: phase-vocoder prev frame present")
        #expect(warm.currentBand != DetectionPolicy.bass.acquire, "precondition: band is a guitar band")

        // 2) Swap policy mid-stream.
        p.setPolicy(.bass)

        // 3) Every reset target must be cleared *before another sample is fed* — the
        //    per-field proof the todo asks for.
        let cold = p.stateProbe
        #expect(p.policy.searchRange == 25...420, "swap must take effect")
        #expect(cold.trackedFrequency == nil, "tracked frequency must reset")
        #expect(cold.currentBand == DetectionPolicy.bass.acquire, "band must reset to the new policy's acquire")
        #expect(!cold.hasPrevFrame, "phase-vocoder prev frame must reset")
        #expect(cold.gateIsCold, "sustain gate must reset")
        #expect(cold.smootherIsCold, "smoother must rebuild (no history)")
        #expect(cold.integratorIsCold, "phase integrator must reset")

        // 4) Integration: the swap doesn't just reset — it re-acquires cleanly. With a
        //    cold gate + cold integrator the first post-swap reading cannot be pre-locked,
        //    and the pipeline must re-lock under .bass (proves the reset didn't break it).
        let postSwap = feed(1.5)
        let first = try #require(postSwap.first, ".bass must still track the tone")
        #expect(!first.isLockIntegrated, "first post-swap reading must re-acquire, not stay locked")
        #expect(postSwap.contains { $0.isLockIntegrated }, "must re-lock under .bass after the cold-start reset")
    }

    /// `unvoicedStreak` is 0 throughout a continuous tone, so the test above can't
    /// exercise its reset line. Warm the streak with a brief silence (kept below the
    /// 8-frame self-reset), then prove `setPolicy` zeroes it.
    @Test func setPolicyResetsUnvoicedStreak() {
        let p = PitchPipeline(sampleRate: fs, a4: 440, method: .mpm, policy: .guitar)
        // Lock first so analysis is live (filled ring), then feed silence in small
        // sub-hop chunks until the unvoiced streak first ticks up — landing in (0, 8).
        _ = p.process(Synth.harmonic(fundamental: 196, sampleRate: fs, seconds: 0.8))
        var streak = 0
        var guardCount = 0
        while streak == 0 && guardCount < 4000 {
            _ = p.process([Float](repeating: 0, count: 64))
            streak = p.stateProbe.unvoicedStreak
            guardCount += 1
        }
        #expect((1...7).contains(p.stateProbe.unvoicedStreak),
                "precondition: unvoiced streak warmed without tripping the >=8 self-reset")

        p.setPolicy(.bass)
        #expect(p.stateProbe.unvoicedStreak == 0, "unvoiced streak must reset on policy swap")
    }
}
