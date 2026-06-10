import Foundation

/// The four reproducible probes behind Plan 06 §2–§3, folded out of the
/// stand-alone `docs/plans/06-accuracy-probes/diagnosis.swift` and into the
/// benchmark module so the *diagnosis itself* becomes a CI regression test
/// ("measure, don't guess" — DESIGN §3, Plan 06 §16). Each returns the numbers
/// the plan quotes; `DiagnosisProbeTests` pins them.
///
/// All math is `Double` and self-contained (independent of the shipping `Float`
/// pipeline) — these probes characterise the *physics and estimator choices*, not
/// the engine, exactly as the plan's diagnosis does.
public enum Diagnosis {

    /// Stiff-string inharmonicity coefficient matching `Synth.inharmonicString`.
    public static let defaultB = 3e-4
    public static let defaultPartials = 10

    // MARK: Shared Double-precision synthesis / DTFT (mirrors the probe script)

    /// Inharmonic stiff-string tone: partial k at `k·f0·√(1+B·k²)`, amp ∝ 1/k.
    static func inharmonic(_ f0: Double, sampleRate fs: Double, seconds: Double,
                           B: Double = defaultB, partials: Int = defaultPartials,
                           amp: Double = 0.5) -> [Double] {
        let n = Int(seconds * fs)
        var out = [Double](repeating: 0, count: n)
        var norm = 0.0
        for k in 1...partials { norm += 1.0 / Double(k) }
        for k in 1...partials {
            let fk = Double(k) * f0 * (1 + B * Double(k * k)).squareRoot()
            if fk >= fs / 2 { break }
            let w = 2 * .pi * fk / fs, a = amp / Double(k) / norm
            for i in 0..<n { out[i] += a * sin(w * Double(i)) }
        }
        return out
    }

    /// Deterministic white noise to a target SNR (xorshift — matches the probe).
    static func addNoise(_ x: [Double], snrDB: Double, seed: UInt64) -> [Double] {
        var s = seed
        func u() -> Double { s ^= s << 13; s ^= s >> 7; s ^= s << 17; return Double(s >> 11) * (1.0 / 9007199254740992.0) }
        func g() -> Double { (-2 * log(max(u(), 1e-12))).squareRoot() * cos(2 * .pi * u()) }
        let p = x.reduce(0) { $0 + $1 * $1 } / Double(x.count)
        let sigma = (p / pow(10, snrDB / 10)).squareRoot()
        return x.map { $0 + sigma * g() }
    }

    /// Single-bin DTFT `Σ x·e^{-jθk}` at frequency `f`.
    static func bin(_ x: ArraySlice<Double>, _ f: Double, sampleRate fs: Double) -> (re: Double, im: Double) {
        let w = 2 * .pi * f / fs
        var re = 0.0, im = 0.0, k = 0
        for v in x { let a = w * Double(k); re += v * cos(a); im -= v * sin(a); k += 1 }
        return (re, im)
    }

    static func cents(_ est: Double, _ truth: Double) -> Double { 1200 * log2(est / truth) }

    // MARK: Probe A — single-fundamental bias vs long integration vs multi-partial

    public struct ProbeA: Sendable, Equatable {
        public let acfFundamentalCents: Double      // ACF + parabolic, one 4096 frame
        public let phaseSlopeFundamentalCents: Double  // phase-slope, fundamental, 1 s
        public let phaseSlope10PartialCents: Double    // phase-slope, 10 partials, k²-weighted
    }

    static func acfParabolic(_ x: [Double], near f0: Double, sampleRate fs: Double) -> Double {
        let n = x.count
        let minLag = max(2, Int(fs / (f0 * 1.5))), maxLag = min(n / 2, Int(fs / (f0 * 0.7)))
        func r(_ t: Int) -> Double { var s = 0.0; for j in 0..<(n - t) { s += x[j] * x[j + t] }; return s }
        var best = minLag, bv = -Double.infinity, t = minLag
        while t <= maxLag { let v = r(t); if v > bv { bv = v; best = t }; t += 1 }
        let y0 = r(best - 1), y1 = r(best), y2 = r(best + 1), d = y0 - 2 * y1 + y2
        return fs / (Double(best) + (abs(d) > 1e-15 ? 0.5 * (y0 - y2) / d : 0))
    }

    static func phaseSlope(_ x: [Double], partial k: Int, f0guess: Double, sampleRate fs: Double, B: Double) -> Double {
        let fk = Double(k) * f0guess * (1 + B * Double(k * k)).squareRoot()
        let block = 2048, hop = 1024
        var ts = [Double](), ph = [Double](), start = 0
        while start + block <= x.count {
            let (re, im) = bin(x[start..<start + block], fk, sampleRate: fs)
            let gg = fk * Double(start) / fs
            ph.append(atan2(im, re) - 2 * .pi * (gg - gg.rounded(.down))); ts.append(Double(start) / fs)
            start += hop
        }
        for i in 1..<ph.count { var d = ph[i] - ph[i - 1]; while d > .pi { d -= 2 * .pi }; while d <= -(.pi) { d += 2 * .pi }; ph[i] = ph[i - 1] + d }
        let n = Double(ts.count), mt = ts.reduce(0, +) / n, mp = ph.reduce(0, +) / n
        var num = 0.0, den = 0.0
        for i in 0..<ts.count { num += (ts[i] - mt) * (ph[i] - mp); den += (ts[i] - mt) * (ts[i] - mt) }
        let fkEst = fk + (den > 0 ? num / den : 0) / (2 * .pi)
        return fkEst / (Double(k) * (1 + B * Double(k * k)).squareRoot())
    }

    public static func probeA(
        trueFrequency truth: Double = 82.41, snrDB: Double = .infinity,
        sampleRate fs: Double = 48_000, B: Double = defaultB, partials: Int = defaultPartials,
        seed: UInt64 = 0xBEEF
    ) -> ProbeA {
        var sig = inharmonic(truth, sampleRate: fs, seconds: 1.0, B: B, partials: partials)
        if snrDB.isFinite { sig = addNoise(sig, snrDB: snrDB, seed: seed) }
        let a = acfParabolic(Array(sig.prefix(4096)), near: truth, sampleRate: fs)
        let c = phaseSlope(sig, partial: 1, f0guess: truth, sampleRate: fs, B: B)
        var ws = 0.0, fsum = 0.0
        for k in 1...partials { fsum += Double(k * k) * phaseSlope(sig, partial: k, f0guess: truth, sampleRate: fs, B: B); ws += Double(k * k) }
        return ProbeA(acfFundamentalCents: cents(a, truth),
                      phaseSlopeFundamentalCents: cents(c, truth),
                      phaseSlope10PartialCents: cents(fsum / ws, truth))
    }

    // MARK: Probe B — DFT peak interpolation bias

    public struct ProbeB: Sendable, Equatable {
        public let parabolicLinearCents: Double  // worst-case over fractional-bin offset
        public let parabolicLogCents: Double
    }

    public static func probeB(sampleRate fs: Double = 48_000, n N: Int = 4096, centerBin m0: Double = 200) -> ProbeB {
        let w = (0..<N).map { 0.5 - 0.5 * cos(2 * .pi * Double($0) / Double(N - 1)) }
        func tone(_ d: Double) -> [Double] {
            let f = (m0 + d) * fs / Double(N), wv = 2 * .pi * f / fs
            return (0..<N).map { w[$0] * cos(wv * Double($0)) }
        }
        func mag(_ x: [Double], _ m: Double) -> Double {
            let c = bin(x[0..<N], m * fs / Double(N), sampleRate: fs); return (c.re * c.re + c.im * c.im).squareRoot()
        }
        var maxLin = 0.0, maxLog = 0.0
        for d in stride(from: -0.45, through: 0.45, by: 0.05) {
            let x = tone(d)
            let a = mag(x, m0 - 1), b = mag(x, m0), c = mag(x, m0 + 1)
            let pLin = 0.5 * (a - c) / (a - 2 * b + c)
            let la = log(a), lb = log(b), lc = log(c), pLog = 0.5 * (la - lc) / (la - 2 * lb + lc)
            maxLin = max(maxLin, abs(cents((m0 + pLin) * fs / Double(N), (m0 + d) * fs / Double(N))))
            maxLog = max(maxLog, abs(cents((m0 + pLog) * fs / Double(N), (m0 + d) * fs / Double(N))))
        }
        return ProbeB(parabolicLinearCents: maxLin, parabolicLogCents: maxLog)
    }

    // MARK: Probe C — CRLB floor + ppm↔cents (delegates to `Crlb`)

    public struct ProbeC: Sendable, Equatable {
        public let crlbSingleCents: Double
        public let crlbHarmonic10Cents: Double
        public let ppm20: Double, ppm44: Double, ppm100: Double
        public let ppmPerCent: Double
    }

    public static func probeC(
        sampleRate fs: Double = 48_000, n N: Int = 4096, snrDB: Double = 40, f0: Double = 82.41
    ) -> ProbeC {
        // Equal-amplitude partials (the probe's convention): Σ k² over k = 1…10.
        let weight = Crlb.harmonicWeight(amplitudes: [Double](repeating: 1, count: 10))
        return ProbeC(
            crlbSingleCents: Crlb.boundCentsSingle(sampleRate: fs, n: N, snrDB: snrDB, f0: f0),
            crlbHarmonic10Cents: Crlb.boundCentsHarmonic(sampleRate: fs, n: N, snrDB: snrDB, f0: f0, harmonicWeight: weight),
            ppm20: Crlb.centsFromPPM(20), ppm44: Crlb.centsFromPPM(44), ppm100: Crlb.centsFromPPM(100),
            ppmPerCent: Crlb.ppmPerCent)
    }

    // MARK: Probe D — joint (f0, B) recovery from partials

    public struct ProbeD: Sendable, Equatable {
        public let recoveredF0: Double
        public let recoveredF0Cents: Double      // error vs truth (≈ 0)
        public let recoveredB: Double
        public let sharpnessN8: Double           // 865.62·B·n² at n = 8
        public let sharpnessN10: Double          // … and n = 10 (≈ benchmark worst case)
    }

    public static func probeD(
        trueFrequency f0t: Double = 82.41, B: Double = defaultB, partials: Int = defaultPartials
    ) -> ProbeD {
        var X = [Double](), Y = [Double]()
        for n in 1...partials {
            let fn = Double(n) * f0t * (1 + B * Double(n * n)).squareRoot()
            X.append(Double(n * n)); Y.append((fn / Double(n)) * (fn / Double(n)))
        }
        let m = Double(partials), mx = X.reduce(0, +) / m, my = Y.reduce(0, +) / m
        var num = 0.0, den = 0.0
        for i in 0..<partials { num += (X[i] - mx) * (Y[i] - my); den += (X[i] - mx) * (X[i] - mx) }
        let slope = num / den, icpt = my - slope * mx, f0r = icpt.squareRoot()
        return ProbeD(recoveredF0: f0r, recoveredF0Cents: cents(f0r, f0t), recoveredB: slope / icpt,
                      sharpnessN8: 865.62 * B * 64, sharpnessN10: 865.62 * B * 100)
    }
}
