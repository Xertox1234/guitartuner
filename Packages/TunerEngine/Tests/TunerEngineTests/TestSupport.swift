import Foundation
@testable import TunerEngine

/// Shared helpers for the engine tests.
enum TestSupport {
    static let fs = 48_000.0

    /// Cents difference between two frequencies.
    static func cents(_ estimate: Double, _ truth: Double) -> Double {
        1200 * log2(estimate / truth)
    }

    /// A Hann-windowed pure-sine frame of length `n` at `frequency` — mirrors
    /// what the pipeline feeds the detectors.
    static func sineFrame(_ frequency: Double, n: Int, sampleRate: Double = fs) -> [Float] {
        var f = Synth.pure(frequency: frequency, sampleRate: sampleRate, seconds: Double(n) / sampleRate + 0.01)
        f = Array(f.prefix(n))
        let w = Windowing.hann(n)
        for i in 0..<n { f[i] *= w[i] }
        return f
    }

    /// A Hann-windowed inharmonic-string frame.
    static func stringFrame(_ frequency: Double, n: Int, B: Double = 3e-4, sampleRate: Double = fs) -> [Float] {
        var f = Synth.inharmonicString(fundamental: frequency, sampleRate: sampleRate,
                                       seconds: Double(n) / sampleRate + 0.01, inharmonicity: B)
        f = Array(f.prefix(n))
        let w = Windowing.hann(n)
        for i in 0..<n { f[i] *= w[i] }
        return f
    }
}
