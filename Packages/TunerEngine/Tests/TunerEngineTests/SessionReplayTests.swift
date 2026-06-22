import Testing
import Foundation
@testable import TunerEngine

/// Float32 fixture codec + the determinism property that makes a recorded WAV a
/// faithful replay of the live pipeline (spec §7).
@Suite struct SessionReplayTests {
    let fs = 48_000.0

    @Test func float32RoundTripIsBitExactIncludingOverUnity() {
        // A >1.0 sample proves the float path does NOT clamp (16-bit would).
        let s: [Float] = [0, 0.5, -0.5, 1.0, -1.0, 1.5, -1.5, 0.123456]
        let data = Fixtures.encodeWAVFloat32(s, sampleRate: fs)
        let decoded = Fixtures.decodeWAV(data)
        #expect(decoded != nil)
        #expect(decoded!.sampleRate == fs)
        #expect(decoded!.samples == s)            // exact, no quantisation, no clamp
    }

    @Test func twoFreshPipelinesAreDeterministic() {
        let s = Synth.harmonic(fundamental: 146.83, sampleRate: fs, seconds: 1.0)   // D3
        let a = PitchPipeline(sampleRate: fs, a4: 440, method: .mpm, targetNote: nil, policy: .guitar).process(s)
        let b = PitchPipeline(sampleRate: fs, a4: 440, method: .mpm, targetNote: nil, policy: .guitar).process(s)
        #expect(!a.isEmpty)
        #expect(a == b)
    }

    @Test func recordedFloat32ReplaysExactly() {
        let s = Synth.harmonic(fundamental: 110.0, sampleRate: fs, seconds: 1.0)    // A2
        let direct = PitchPipeline(sampleRate: fs, a4: 440, method: .mpm, targetNote: nil, policy: .guitar).process(s)
        let decoded = Fixtures.decodeWAV(Fixtures.encodeWAVFloat32(s, sampleRate: fs))!.samples
        let replayed = PitchPipeline(sampleRate: fs, a4: 440, method: .mpm, targetNote: nil, policy: .guitar).process(decoded)
        #expect(!direct.isEmpty)
        #expect(replayed == direct)
    }
}
