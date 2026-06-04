// Plan 06 — reproducible diagnosis probes.
//
// Every number quoted in `docs/plans/06-accuracy-engine.md` §2 (and the CRLB /
// ppm tables in §3, §7) is regenerated here, self-contained, on the repo's Swift
// toolchain. "Measure, don't guess" (DESIGN §3) — so the *diagnosis* is a script
// you can run, not a claim you have to trust.
//
//   swiftc -O docs/plans/06-accuracy-probes/diagnosis.swift -o /tmp/diag && /tmp/diag
//
// Phase P0 folds these into `Packages/TunerEngine/.../Bench/` as regression tests.

import Foundation

let fs = 48_000.0
let B = 3e-4            // stiff-string inharmonicity coeff (matches Synth.inharmonicString)
let partials = 10

// ── shared synthesis (the benchmark's own stiff-string model) ───────────────
func inharmonic(_ f0: Double, seconds: Double, amp: Double = 0.5) -> [Double] {
    let n = Int(seconds * fs)
    var out = [Double](repeating: 0, count: n)
    var norm = 0.0
    for k in 1...partials { norm += 1.0 / Double(k) }
    for k in 1...partials {
        let fk = Double(k) * f0 * (1 + B * Double(k*k)).squareRoot()
        if fk >= fs/2 { break }
        let w = 2 * .pi * fk / fs, a = amp / Double(k) / norm
        for i in 0..<n { out[i] += a * sin(w * Double(i)) }
    }
    return out
}
func addNoise(_ x: [Double], snrDB: Double, seed: UInt64) -> [Double] {
    var s = seed
    func u() -> Double { s ^= s << 13; s ^= s >> 7; s ^= s << 17; return Double(s >> 11) * (1.0/9007199254740992.0) }
    func g() -> Double { (-2*log(max(u(),1e-12))).squareRoot() * cos(2 * .pi * u()) }
    let p = x.reduce(0){$0+$1*$1}/Double(x.count)
    let sigma = (p / pow(10, snrDB/10)).squareRoot()
    return x.map { $0 + sigma*g() }
}
func bin(_ x: ArraySlice<Double>, _ f: Double) -> (re: Double, im: Double) {
    let w = 2 * .pi * f / fs; var re = 0.0, im = 0.0, k = 0
    for v in x { let a = w*Double(k); re += v*cos(a); im -= v*sin(a); k += 1 }
    return (re, im)
}
func cents(_ est: Double, _ truth: Double) -> Double { 1200*log2(est/truth) }

// ── Probe A: single-fundamental bias vs long-integration vs multi-partial ───
func acfParabolic(_ x: [Double], near f0: Double) -> Double {
    let n = x.count
    let minLag = max(2, Int(fs/(f0*1.5))), maxLag = min(n/2, Int(fs/(f0*0.7)))
    func r(_ t: Int) -> Double { var s=0.0; for j in 0..<(n-t){ s += x[j]*x[j+t] }; return s }
    var best = minLag, bv = -Double.infinity, t = minLag
    while t <= maxLag { let v = r(t); if v>bv {bv=v;best=t}; t += 1 }
    let y0=r(best-1), y1=r(best), y2=r(best+1), d=y0 - 2*y1 + y2
    return fs / (Double(best) + (abs(d)>1e-15 ? 0.5*(y0-y2)/d : 0))
}
func phaseSlope(_ x: [Double], partial k: Int, f0guess: Double) -> Double {
    let fk = Double(k)*f0guess*(1+B*Double(k*k)).squareRoot()
    let block = 2048, hop = 1024
    var ts = [Double](), ph = [Double](), start = 0
    while start + block <= x.count {
        let (re,im) = bin(x[start..<start+block], fk)
        let gg = fk*Double(start)/fs
        ph.append(atan2(im,re) - 2 * .pi*(gg - gg.rounded(.down))); ts.append(Double(start)/fs)
        start += hop
    }
    for i in 1..<ph.count { var d = ph[i]-ph[i-1]; while d > .pi { d -= 2 * .pi }; while d <= -(.pi) { d += 2 * .pi }; ph[i]=ph[i-1]+d }
    let n = Double(ts.count), mt = ts.reduce(0,+)/n, mp = ph.reduce(0,+)/n
    var num=0.0, den=0.0
    for i in 0..<ts.count { num += (ts[i]-mt)*(ph[i]-mp); den += (ts[i]-mt)*(ts[i]-mt) }
    let fkEst = fk + (den>0 ? num/den : 0)/(2 * .pi)
    return fkEst / (Double(k)*(1+B*Double(k*k)).squareRoot())
}
func probeA() {
    print("── Probe A: stiff-string E2 (82.41 Hz), single-fundamental vs integration ──")
    let truth = 82.41
    for snr in [Double.infinity, 40, 20] {
        var sig = inharmonic(truth, seconds: 1.0)
        if snr.isFinite { sig = addNoise(sig, snrDB: snr, seed: 0xBEEF) }
        let a = acfParabolic(Array(sig.prefix(4096)), near: truth)
        let c = phaseSlope(sig, partial: 1, f0guess: truth)
        var ws=0.0, fsum=0.0
        for k in 1...partials { fsum += Double(k*k)*phaseSlope(sig, partial: k, f0guess: truth); ws += Double(k*k) }
        let label = snr.isFinite ? "\(Int(snr)) dB" : "clean"
        print(String(format: "  %-6@  ACF+parab(fund,4096) %+7.3f¢ | phaseslope(fund,1s) %+.4f¢ | 10part k² %+.4f¢",
                     label as NSString, cents(a,truth), cents(c,truth), cents(fsum/ws,truth)))
    }
}

// ── Probe B: DFT peak interpolation bias (the reliable two) ─────────────────
func probeB() {
    print("── Probe B: pure tone N=4096 Hann, worst-case interpolation bias ──")
    let N = 4096, m0 = 200.0
    let w = (0..<N).map { 0.5-0.5*cos(2 * .pi*Double($0)/Double(N-1)) }
    func tone(_ d: Double) -> [Double] {
        let f = (m0+d)*fs/Double(N), wv = 2 * .pi*f/fs
        return (0..<N).map { w[$0]*cos(wv*Double($0)) }
    }
    func mag(_ x:[Double], _ m:Double)->Double { let c=bin(x[0..<N],m*fs/Double(N)); return (c.re*c.re+c.im*c.im).squareRoot() }
    var maxLin = 0.0, maxLog = 0.0
    for d in stride(from: -0.45, through: 0.45, by: 0.05) {
        let x = tone(d)
        let a=mag(x,199), b=mag(x,200), c=mag(x,201)
        let pLin = 0.5*(a-c)/(a - 2*b + c)
        let la=log(a), lb=log(b), lc=log(c), pLog = 0.5*(la-lc)/(la - 2*lb + lc)
        maxLin = max(maxLin, abs(cents((m0+pLin)*fs/Double(N), (m0+d)*fs/Double(N))))
        maxLog = max(maxLog, abs(cents((m0+pLog)*fs/Double(N), (m0+d)*fs/Double(N))))
    }
    print(String(format: "  parabolic(linear mag) %.4f¢  (= 5.3%% of a bin)   parabolic(log mag) %.4f¢", maxLin, maxLog))
}

// ── Probe C: CRLB floor + ppm↔cents ─────────────────────────────────────────
func probeC() {
    print("── Probe C: CRLB floor (4096@48k, 82 Hz, 40 dB) + clock floor ──")
    func crlb(_ sumK2: Double) -> Double {
        let snr = pow(10, 40.0/10), Nn = 4096.0
        let varF = 6*fs*fs / (pow(2 * .pi,2)*snr*Nn*(Nn*Nn-1)*sumK2)
        return 1200/log(2.0) * varF.squareRoot()/82.41
    }
    let p10 = (1...10).reduce(0.0){$0+Double($1*$1)}
    print(String(format: "  CRLB single-tone %.4f¢   harmonic P=10 %.5f¢", crlb(1), crlb(p10)))
    for ppm in [20.0,44,100] { print(String(format: "  %.0f ppm = %.4f¢ absolute", ppm, 1200*log2(1+ppm/1e6))) }
    print(String(format: "  1 cent = %.1f ppm", 1e6*(pow(2,1.0/1200)-1)))
}

// ── Probe D: joint (f0, B) recovery from partials ───────────────────────────
func probeD() {
    print("── Probe D: joint (f0,B) recovery — (f_n/n)² vs n² regression ──")
    let f0t = 82.41
    var X=[Double](), Y=[Double]()
    for n in 1...partials {
        let fn = Double(n)*f0t*(1+B*Double(n*n)).squareRoot()
        X.append(Double(n*n)); Y.append((fn/Double(n))*(fn/Double(n)))
    }
    let m = Double(partials), mx=X.reduce(0,+)/m, my=Y.reduce(0,+)/m
    var num=0.0, den=0.0
    for i in 0..<partials { num+=(X[i]-mx)*(Y[i]-my); den+=(X[i]-mx)*(X[i]-mx) }
    let slope=num/den, icpt=my-slope*mx, f0r=icpt.squareRoot()
    print(String(format: "  recovered f0 %.5f Hz (err %.5f¢), B %.3e (true %.3e)", f0r, cents(f0r,f0t), slope/icpt, B))
    print(String(format: "  partial sharpness: n=8 %.2f¢  n=10 %.2f¢  (≈ benchmark worst-case 25.7¢)",
                 865.62*B*64, 865.62*B*100))
}

probeA(); probeB(); probeC(); probeD()
