// swift-tools-version: 5.9
import PackageDescription

// TunerEngine — the shared, UI-free audio + DSP package that turns live (or
// file / synthesized) audio into precise pitch readings: nearest note, cents,
// confidence, and the strobe phase. Pure Swift + Accelerate/vDSP, no third-party
// deps, no networking. Platforms match the app (iOS 17 / macOS 14).
//
//  • TunerEngine  — library: capture (AVAudioEngine, on-device) + the pipeline,
//                   plus the benchmark stimuli/metrics so they're unit-testable.
//  • Benchmark    — headless executable: runs the accuracy harness on synthesized
//                   (and optional file) input and writes the CSV + Markdown report.
let package = Package(
    name: "TunerEngine",
    platforms: [
        .iOS(.v17),
        .macOS(.v14)
    ],
    products: [
        .library(name: "TunerEngine", targets: ["TunerEngine"]),
        .executable(name: "Benchmark", targets: ["Benchmark"])
    ],
    targets: [
        .target(
            name: "TunerEngine"
        ),
        .executableTarget(
            name: "Benchmark",
            dependencies: ["TunerEngine"]
        ),
        .testTarget(
            name: "TunerEngineTests",
            dependencies: ["TunerEngine"]
        )
    ]
)
