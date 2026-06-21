import Testing
import Foundation
@testable import TunerEngine

/// Headless checks on the reference-tone synthesizer (the output path — distinct
/// from capture/analysis). Verifies it is silent, click-free, harmonically rich,
/// bounded, and plays the requested pitch.
@Suite struct ToneSynthTests {
    let fs = 48_000.0

    /// Render `seconds` of audio in 512-frame blocks (like the live source node).
    private func render(_ synth: inout ToneSynth, seconds: Double) -> [Float] {
        let total = Int(fs * seconds)
        var out: [Float] = []
        var i = 0
        while i < total {
            let n = min(512, total - i)
            var buf = [Float](repeating: 0, count: n)
            synth.render(into: &buf)
            out += buf
            i += n
        }
        return out
    }

    /// Phase-independent magnitude at `freq` (a single-bin Goertzel).
    private func magnitude(_ x: [Float], freq: Double) -> Double {
        let w = 2 * Double.pi * freq / fs
        let coeff = 2 * cos(w)
        var s1 = 0.0, s2 = 0.0
        for v in x {
            let s0 = Double(v) + coeff * s1 - s2
            s2 = s1; s1 = s0
        }
        let real = s1 - s2 * cos(w)
        let imag = s2 * sin(w)
        return (real * real + imag * imag).squareRoot() / Double(x.count)
    }

    private func rms(_ x: [Float]) -> Double {
        (x.reduce(0.0) { $0 + Double($1) * Double($1) } / Double(max(1, x.count))).squareRoot()
    }

    @Test func silentAtZeroGain() {
        var s = ToneSynth(sampleRate: fs, frequency: 440, targetGain: 0)
        let out = render(&s, seconds: 0.05)
        #expect((out.map { abs($0) }.max() ?? 0) < 1e-6)
        #expect(abs(s.currentGain - 0) < 1e-9)
    }

    @Test func rampsUpBoundedAndAudible() {
        var s = ToneSynth(sampleRate: fs, frequency: 440, targetGain: 0.8)
        let out = render(&s, seconds: 0.1)
        #expect(s.currentGain > 0.7)                       // reaches near target
        #expect((out.map { abs($0) }.max() ?? 0) <= 1.0)  // never clips
        #expect(rms(out) > 0.05)                          // audible
        #expect(!out.contains { $0.isNaN || $0.isInfinite })
    }

    @Test func rampsDownToSilence() {
        var s = ToneSynth(sampleRate: fs, frequency: 220, targetGain: 1)
        _ = render(&s, seconds: 0.1)
        s.targetGain = 0
        _ = render(&s, seconds: 0.2)
        #expect(s.currentGain < 1e-3)
    }

    @Test func harmonicContentAndDominantFundamental() {
        var s = ToneSynth(sampleRate: fs, frequency: 440, targetGain: 1)
        let out = Array(render(&s, seconds: 0.3).suffix(8192))        // steady state
        let f1 = magnitude(out, freq: 440)
        let f2 = magnitude(out, freq: 880)
        let f3 = magnitude(out, freq: 1320)
        let between = magnitude(out, freq: 660)                        // 1.5f — no partial here
        #expect(f1 > f2)                                   // fundamental dominant
        #expect(f2 > 0.001)                               // a real 2nd partial
        #expect(f3 > 0.0005)                             // a real 3rd partial
        #expect(f1 > between * 5)                         // tonal, not noisy
    }

    @Test func playsRequestedPitch() {
        var s = ToneSynth(sampleRate: fs, frequency: Pitch.frequency(midi: 69), targetGain: 1) // A4
        let out = Array(render(&s, seconds: 0.25).suffix(8192))
        let at440 = magnitude(out, freq: 440)
        #expect(at440 > magnitude(out, freq: 415) * 5)
        #expect(at440 > magnitude(out, freq: 466) * 5)
    }

    @Test func phaseContinuousAcrossRetune() {
        var s = ToneSynth(sampleRate: fs, frequency: 440, targetGain: 1)
        _ = render(&s, seconds: 0.05)                                 // gain settled
        var a = [Float](repeating: 0, count: 256); s.render(into: &a)
        s.frequency = 330                                             // retune mid-stream
        var b = [Float](repeating: 0, count: 256); s.render(into: &b)
        // The waveform value depends only on the (carried) phase, so the seam is no
        // bigger than a normal sample step — i.e. no click on retune.
        let seam = abs(Double(b[0]) - Double(a[a.count - 1]))
        let maxStep = (1..<a.count).map { abs(Double(a[$0]) - Double(a[$0 - 1])) }.max() ?? 1
        #expect(seam < maxStep + 0.05)
    }
}
