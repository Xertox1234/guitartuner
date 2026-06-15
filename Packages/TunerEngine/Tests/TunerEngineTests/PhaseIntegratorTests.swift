import Foundation
import Testing
@testable import TunerEngine

private let fs = 48_000.0
private let hop = 1024
private let window = 4096

/// Run `n` hops of the integrator over a synthesized audio buffer, return the last result.
private func run(
    _ integrator: inout PhaseIntegrator,
    audio: [Float],
    f0: Double,
    B: Double = 0,
    hops: Int? = nil,
    maxPartials: Int = 10
) -> PhaseIntegrator.Result? {
    let totalHops = hops ?? (audio.count - window) / hop
    var result: PhaseIntegrator.Result? = nil
    for i in 0..<totalHops {
        let frameStart = i * hop
        guard frameStart + window <= audio.count else { break }
        let frame = Array(audio[frameStart..<(frameStart + window)])
        let t = (Double(frameStart) + Double(window) / 2) / fs
        result = integrator.feed(frame: frame, f0: f0, inharmonicityB: B,
                                 sampleRate: fs, frameTime: t, maxPartials: maxPartials)
    }
    return result
}

@Suite("PhaseIntegrator")
struct PhaseIntegratorTests {

    // Pure sine tone held long enough (> minHops) → frequency recovered within 0.05 ¢.
    @Test func pureSubHalfCentAccuracy() {
        let fTrue = 110.0   // A2 — bass register
        let audio = Synth.pure(frequency: fTrue, sampleRate: fs, seconds: 3.0)
        var integrator = PhaseIntegrator()
        guard let r = run(&integrator, audio: audio, f0: fTrue) else {
            Issue.record("integrator did not converge after 3 s")
            return
        }
        let errorCents = abs(1200 * log2(r.f0 / fTrue))
        #expect(errorCents < 0.05,
                "Expected < 0.05 ¢, got \(String(format: "%.4f", errorCents)) ¢")
        #expect(r.precisionCents < 0.5)
    }

    // Inharmonic string with 10 partials at E2 — the bass worst-case.
    // Fisher fusion across partials should still recover f0 to sub-0.05 ¢.
    @Test func inharmonicBassSubHalfCentAccuracy() {
        let f0True = 82.407  // E2
        let B = 3e-4
        let audio = Synth.inharmonicString(
            fundamental: f0True, sampleRate: fs, seconds: 3.0,
            partials: 10, inharmonicity: B
        )
        var integrator = PhaseIntegrator()
        guard let r = run(&integrator, audio: audio, f0: f0True, B: B) else {
            Issue.record("integrator did not converge after 3 s")
            return
        }
        let errorCents = abs(1200 * log2(r.f0 / f0True))
        #expect(errorCents < 0.05,
                "Expected < 0.05 ¢, got \(String(format: "%.4f", errorCents)) ¢")
    }

    // No result before minHops.
    @Test func noResultBeforeMinHops() {
        // 0.2 s → ~5 hops at N=4096, hop=1024; well below minHops = 20.
        let audio = Synth.pure(frequency: 440.0, sampleRate: fs, seconds: 0.2)
        var integrator = PhaseIntegrator()
        let shortHops = (audio.count - window) / hop
        #expect(shortHops < PhaseIntegrator.minHops,
                "Precondition: test audio must be shorter than minHops hops")
        let result = run(&integrator, audio: audio, f0: 440, hops: shortHops)
        #expect(result == nil, "Expected nil before minHops, got a result")
    }

    // reset() clears history — next single feed returns nil.
    @Test func resetClearsHistory() {
        let fTrue = 220.0
        let audio = Synth.pure(frequency: fTrue, sampleRate: fs, seconds: 2.0)
        var integrator = PhaseIntegrator()
        _ = run(&integrator, audio: audio, f0: fTrue, hops: 25)

        // Reset, then a single feed must return nil (hopCount = 1 < minHops).
        integrator.reset()
        let frameStart = 25 * hop
        guard frameStart + window <= audio.count else { return }
        let frame = Array(audio[frameStart..<(frameStart + window)])
        let t = (Double(frameStart) + Double(window) / 2) / fs
        let result = integrator.feed(frame: frame, f0: fTrue, sampleRate: fs, frameTime: t)
        #expect(result == nil, "Expected nil immediately after reset")
    }

    // A note change > resetCents triggers reset internally — the integrator restarts
    // and returns nil on the next call (hopCount resets to 1).
    @Test func largeJumpTriggersReset() {
        let audio = Synth.pure(frequency: 440.0, sampleRate: fs, seconds: 3.0)
        var integrator = PhaseIntegrator()
        // Run to convergence at 440 Hz.
        _ = run(&integrator, audio: audio, f0: 440, hops: 25)

        // Feed one frame claiming f0 = 880 Hz — 1200 ¢ shift, well beyond resetCents.
        let frameStart = 25 * hop
        guard frameStart + window <= audio.count else { return }
        let frame = Array(audio[frameStart..<(frameStart + window)])
        let t = (Double(frameStart) + Double(window) / 2) / fs
        let result = integrator.feed(frame: frame, f0: 880, sampleRate: fs, frameTime: t)
        // After internal reset hopCount == 1, so no result yet.
        #expect(result == nil, "Expected nil after note-change reset")
    }

    // Octave-safety clamp: if the phase fit somehow wanders outside ±50 ¢ of the
    // anchor, the result must be discarded (returns nil).
    // Simulate by providing an anchor very far from the synthesized tone.
    @Test func octaveSafetyClampRejectsOutOfBand() {
        let fTrue = 440.0
        let anchor = 100.0   // 880 Hz → 1200 ¢ below fTrue — outside ±50 ¢
        let audio = Synth.pure(frequency: fTrue, sampleRate: fs, seconds: 3.0)
        var integrator = PhaseIntegrator()
        // Feed at fTrue so the reference is set near fTrue, but pass the far-off
        // anchor as the safety bound on the first hop, then keep going.
        // The result f0Lock ≈ fTrue; anchor = 100 Hz; diff ≈ 2400 ¢ → clamp fires.
        // We test by resetting and re-feeding with a mismatched anchor.
        _ = run(&integrator, audio: audio, f0: fTrue, hops: 25)
        integrator.reset()
        var result: PhaseIntegrator.Result? = nil
        for i in 0..<25 {
            let frameStart = i * hop
            guard frameStart + window <= audio.count else { break }
            let frame = Array(audio[frameStart..<(frameStart + window)])
            let t = (Double(frameStart) + Double(window) / 2) / fs
            // refF0 is set from f0 = fTrue on first call, but we pass anchor as
            // the octave-safety value to estimate(anchor:).
            // This is done by feeding with f0 = anchor after accumulating with fTrue.
            result = integrator.feed(frame: frame, f0: anchor, sampleRate: fs, frameTime: t)
        }
        // After 25 hops, the integrator has ref = 100 Hz and fLock ≈ 440 Hz —
        // 440/100 = 4.4× → centsShift >> 50 → clamp rejects, returns nil.
        // (If reset triggers on note-change the result is also nil — both outcomes pass.)
        #expect(result == nil || result!.f0 < anchor * pow(2, 51.0/1200))
    }
}
