import Foundation

/// Deterministic, seedable RNG (SplitMix64) so the benchmark's noise is
/// reproducible — the published numbers don't wander run to run.
public struct SeededRNG: RandomNumberGenerator {
    private var state: UInt64
    public init(seed: UInt64 = 0x9E3779B97F4A7C15) { state = seed }
    public mutating func next() -> UInt64 {
        state &+= 0x9E3779B97F4A7C15
        var z = state
        z = (z ^ (z >> 30)) &* 0xBF58476D1CE4E5B9
        z = (z ^ (z >> 27)) &* 0x94D049BB133111EB
        return z ^ (z >> 31)
    }
}

/// Synthesizers for the accuracy harness: pure, harmonic, and **inharmonic
/// string** tones at a known frequency + cents offset, plus white-noise mixing at
/// a target SNR. The inharmonic model is the point — real strings are stiff, so
/// partials sit slightly sharp of integer multiples, which is exactly what biases
/// naive spectral-peak trackers (DESIGN §3, Plan 01 §6).
public enum Synth {

    /// Detune a frequency by a number of cents.
    public static func detune(_ f: Double, cents: Double) -> Double {
        f * pow(2, cents / 1200)
    }

    /// A pure sine. `amplitude` is peak; `phase0` in radians.
    public static func pure(
        frequency: Double, sampleRate: Double, seconds: Double,
        amplitude: Double = 0.5, phase0: Double = 0
    ) -> [Float] {
        let n = Int(seconds * sampleRate)
        var out = [Float](repeating: 0, count: n)
        let w = 2 * Double.pi * frequency / sampleRate
        for i in 0..<n { out[i] = Float(amplitude * sin(w * Double(i) + phase0)) }
        return out
    }

    /// A harmonic tone: partials at exact integer multiples, amplitude ∝ 1/k.
    public static func harmonic(
        fundamental f0: Double, sampleRate: Double, seconds: Double,
        partials: Int = 8, amplitude: Double = 0.5
    ) -> [Float] {
        let n = Int(seconds * sampleRate)
        var out = [Float](repeating: 0, count: n)
        var norm = 0.0
        for k in 1...partials { norm += 1.0 / Double(k) }
        for k in 1...partials {
            let fk = f0 * Double(k)
            guard fk < sampleRate / 2 else { break }
            let w = 2 * Double.pi * fk / sampleRate
            let a = amplitude / Double(k) / norm
            for i in 0..<n { out[i] += Float(a * sin(w * Double(i))) }
        }
        return out
    }

    /// An **inharmonic** string tone: partial k sits at
    /// `k·f0·√(1 + B·k²)` (the stiff-string law), amplitude ∝ 1/k. `B` is the
    /// inharmonicity coefficient (~1e-4 plain guitar, larger for wound bass).
    public static func inharmonicString(
        fundamental f0: Double, sampleRate: Double, seconds: Double,
        partials: Int = 10, inharmonicity B: Double = 3e-4, amplitude: Double = 0.5
    ) -> [Float] {
        let n = Int(seconds * sampleRate)
        var out = [Float](repeating: 0, count: n)
        var norm = 0.0
        for k in 1...partials { norm += 1.0 / Double(k) }
        for k in 1...partials {
            let fk = Double(k) * f0 * (1 + B * Double(k * k)).squareRoot()
            guard fk < sampleRate / 2 else { break }
            let w = 2 * Double.pi * fk / sampleRate
            let a = amplitude / Double(k) / norm
            for i in 0..<n { out[i] += Float(a * sin(w * Double(i))) }
        }
        return out
    }

    /// A pluck amplitude envelope (fast attack, exponential decay) — for
    /// time-to-lock: the gate must skip the noisy attack and lock the sustain.
    public static func applyPluckEnvelope(
        _ signal: inout [Float], sampleRate: Double,
        attack: Double = 0.005, decayTau: Double = 1.2
    ) {
        let a = max(1, Int(attack * sampleRate))
        for i in signal.indices {
            let t = Double(i) / sampleRate
            let env: Double
            if i < a { env = Double(i) / Double(a) }
            else { env = exp(-(t - attack) / decayTau) }
            signal[i] = Float(Double(signal[i]) * env)
        }
    }

    /// Mix white noise into a copy of `signal` to hit a target SNR (dB), measured
    /// on RMS. `snrDB = .infinity` returns the clean signal.
    public static func addNoise(
        to signal: [Float], snrDB: Double, rng: inout SeededRNG
    ) -> [Float] {
        guard snrDB.isFinite else { return signal }
        let sigPower = signal.reduce(0.0) { $0 + Double($1) * Double($1) } / Double(max(1, signal.count))
        guard sigPower > 0 else { return signal }
        let noisePower = sigPower / pow(10, snrDB / 10)
        let sigma = noisePower.squareRoot()
        var out = signal
        for i in out.indices {
            out[i] += Float(sigma * gaussian(&rng))
        }
        return out
    }

    /// Standard-normal sample via Box–Muller.
    static func gaussian(_ rng: inout SeededRNG) -> Double {
        let u1 = Double.random(in: Double.leastNonzeroMagnitude...1, using: &rng)
        let u2 = Double.random(in: 0...1, using: &rng)
        return (-2 * log(u1)).squareRoot() * cos(2 * Double.pi * u2)
    }
}
