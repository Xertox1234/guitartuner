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

// Optionally persist the artifacts.
if let out = arg("--out") {
    let dir = URL(fileURLWithPath: out, isDirectory: true)
    try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
    try? report.markdown.write(to: dir.appendingPathComponent("accuracy.md"), atomically: true, encoding: .utf8)
    try? report.csv.write(to: dir.appendingPathComponent("accuracy.csv"), atomically: true, encoding: .utf8)
    FileHandle.standardError.write("wrote accuracy.md + accuracy.csv to \(out)\n".data(using: .utf8)!)
}

// CI sanity gate: catch gross regressions (octave errors on clean tones, wild
// error, or a stuck lock) without being flaky on tight tolerances.
if flag("--ci") {
    let s = report.summary
    var failures: [String] = []
    if s.octaveErrorRate > 0 { failures.append("octave-error rate \(s.octaveErrorRate * 100)% > 0") }
    if s.cleanAbsCents > 10 { failures.append("clean abs error \(s.cleanAbsCents)¢ > 10") }
    if s.lockMSMedian > 350 { failures.append("median lock \(s.lockMSMedian)ms > 350") }
    if !failures.isEmpty {
        FileHandle.standardError.write(("BENCHMARK CI FAIL: " + failures.joined(separator: "; ") + "\n").data(using: .utf8)!)
        exit(1)
    }
    FileHandle.standardError.write("benchmark CI gate passed\n".data(using: .utf8)!)
}
