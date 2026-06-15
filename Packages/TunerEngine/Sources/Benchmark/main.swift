import Foundation
import TunerEngine

// Headless accuracy benchmark. Runs on synthesized input (no audio device), so
// it works in CI. Prints a Markdown report + a delimited CSV block to stdout and,
// with `--out <dir>`, writes accuracy.md / accuracy.csv.
//
//   swift run -c release Benchmark                 # MPM, print report
//   swift run -c release Benchmark --compare       # + MPM/YIN/hybrid table
//   swift run -c release Benchmark --out docs/benchmarks --ci

func arg(_ name: String) -> String? {
    let a = CommandLine.arguments
    guard let i = a.firstIndex(of: name), i + 1 < a.count else { return nil }
    return a[i + 1]
}
func flag(_ name: String) -> Bool { CommandLine.arguments.contains(name) }

let method = DetectionMethod(rawValue: arg("--method") ?? "mpm") ?? .mpm
let dateLabel = arg("--date") ?? "Generated \(ISO8601DateFormatter().string(from: Date()))"

// MPM vs YIN vs hybrid — let the data choose the default.
if flag("--compare") {
    print("## Method comparison (representative subset)\n")
    print("| Method | abs ¢ | σ ¢ | worst ¢ | octave err | lock ms | n |")
    print("|---|---|---|---|---|---|---|")
    for s in BenchmarkSuite.compareMethods() {
        let row = "| \(s.method.rawValue) | "
            + String(format: "%.2f", s.cleanAbsCents) + " | "
            + String(format: "%.2f", s.cleanSigma) + " | "
            + String(format: "%.2f", s.worstAbsCents) + " | "
            + String(format: "%.1f", s.octaveErrorRate * 100) + "% | "
            + String(format: "%.0f", s.lockMSMedian) + " | \(s.cases) |"
        print(row)
    }
    print("")
}

let report = BenchmarkSuite.run(method: method, dateLabel: dateLabel)

// The report (also the committed spec).
print(report.markdown)

// Machine-extractable CSV (for pulling measured numbers out of CI logs).
print("\n===BENCHMARK-CSV-BEGIN===")
print(report.csv)
print("===BENCHMARK-CSV-END===")

// Optional real-DI fixtures (out-of-CI by design): score recorded WAVs through
// the same CaseRunner as the synthetic bench. Skipped silently if the dir is
// absent/empty, so CI stays synthetic/headless (Plan 06 §9).
if let dir = arg("--fixtures") {
    let results = Fixtures.run(directory: URL(fileURLWithPath: dir, isDirectory: true), method: method)
    print(Fixtures.markdown(results))
    FileHandle.standardError.write("fixtures scored: \(results.count)\n".data(using: .utf8)!)
}

// Optionally persist the artifacts.
if let out = arg("--out") {
    let dir = URL(fileURLWithPath: out, isDirectory: true)
    try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
    try? report.markdown.write(to: dir.appendingPathComponent("accuracy.md"), atomically: true, encoding: .utf8)
    try? report.csv.write(to: dir.appendingPathComponent("accuracy.csv"), atomically: true, encoding: .utf8)
    FileHandle.standardError.write("wrote accuracy.md + accuracy.csv to \(out)\n".data(using: .utf8)!)
}

// CI gate. Hard invariants must always hold; the soft gates are ratcheted to
// today's measured numbers + margin and tightened only as the phase that earns
// them lands (Plan 06 §9, §10). They are intentionally loose enough not to flake
// on platform float differences (macOS vDSP vs the scalar fallback).
if flag("--ci") {
    let s = report.summary
    var failures: [String] = []

    // Hard invariants — never regress.
    if s.octaveErrorRate > 0 { failures.append("clean octave-error rate \(s.octaveErrorRate * 100)% > 0") }
    if s.stressOctaveErrors > 0 { failures.append("stress octave errors \(s.stressOctaveErrors) > 0 (weak/missing-fund/vibrato must hold the octave)") }

    // Non-regression gates (today's numbers in comments; P1+P2+P3+P2r baseline).
    if s.cleanAbsCents > 0.25 { failures.append("clean abs \(s.cleanAbsCents)¢ > 0.25") }   // P1+P3: ~0.10¢
    if s.worstAbsCents > 2.5 { failures.append("worst abs \(s.worstAbsCents)¢ > 2.5") }     // P2r: ~1.72¢
    if s.bassAbsCents > 0.35 { failures.append("bass abs \(s.bassAbsCents)¢ > 0.35") }      // P2+P3: ~0.13¢
    // P1+P3 earned these — spectral refine + long-window phase-slope lock.
    if s.highAbsCents > 0.2 { failures.append("high abs \(s.highAbsCents)¢ > 0.2") }        // P1+P3: ~0.09¢
    if s.midAbsCents > 0.2 { failures.append("mid abs \(s.midAbsCents)¢ > 0.2") }           // P1+P3: ~0.09¢
    if s.lockSigma > 0.30 { failures.append("lock σ \(s.lockSigma)¢ > 0.30") }              // P3: ~0.12¢
    if s.lockMSMedian > 350 { failures.append("median lock \(s.lockMSMedian)ms > 350") }    // today 43 ms

    // TODO gates, unlocked phase-by-phase (assert-ready, kept off until earned):
    //   P3 multi-partial Fisher gain:    lock σ < 0.05¢ (requires reliable B and clean partials)
    //   P4 (clock calibration):          absolute-pitch honesty copy + calibration flow

    if !failures.isEmpty {
        FileHandle.standardError.write(("BENCHMARK CI FAIL: " + failures.joined(separator: "; ") + "\n").data(using: .utf8)!)
        exit(1)
    }
    let pass = "benchmark CI gate passed (clean abs \(String(format: "%.2f", s.cleanAbsCents))¢, "
        + "high \(String(format: "%.2f", s.highAbsCents))¢, mid \(String(format: "%.2f", s.midAbsCents))¢, "
        + "bass \(String(format: "%.2f", s.bassAbsCents))¢, lock σ \(String(format: "%.2f", s.lockSigma))¢, "
        + "worst \(String(format: "%.2f", s.worstAbsCents))¢, octave \(s.octaveErrorRate * 100)% / stress \(s.stressOctaveErrors))\n"
    FileHandle.standardError.write(pass.data(using: .utf8)!)
}
