# Audit CHANGELOG

Deduplication index for all findings surfaced across audit runs. Before adding a finding to a new audit, check here to avoid re-surfacing already-verified issues.

---

## 2026-06-15 — full (automated, 5 agents)

| Finding | File | Severity | Status |
|---------|------|----------|--------|
| CI benchmark gate contradicts committed spec — relaxed 2.5¢ → 4.0¢ | `Packages/TunerEngine/Sources/Benchmark/main.swift` | Critical | ✅ verified |
| Missing triple-buffer semaphore in StrobeRenderer | `LumaDesignSystem/Strobe/MetalStrobe.swift` | Critical | ✅ verified |
| Bloom activates without confidence gate — false-lock visual | `AuroraStrobe.swift`, `RadialStrobe.swift`, `MetalStrobe.swift` | High | ✅ verified |
| StrobeInput contract — Double→Float, isIdle added | `LumaDesignSystem/Strobe/StrobeInput.swift` + 11 callers | High | ✅ verified |
| PrivacyInfo.xcprivacy empty collected-data types | `App/PrivacyInfo.xcprivacy` | High | ✅ verified |
| AudioCapture RT-thread allocation (scratch buffer resize) | `TunerEngine/Capture/AudioCapture.swift` | High | ✅ verified |
| AudioCapture force-unwrap on RT thread | `TunerEngine/Capture/AudioCapture.swift` | High | ✅ verified |
| BenchmarkTests tolerance 48× too loose | `TunerEngineTests/BenchmarkTests.swift` | High | ✅ verified |
| testCaseRunnerScoresCleanTone lockStats always empty | `TunerEngineTests/BenchmarkTests.swift` | High | ✅ verified |
| spectralRefineMinHz duplicates AnalysisConfig.midLowHz | `TunerEngine/Pipeline/PitchPipeline.swift` | Medium | ⏸ todo: docs/todos/medium-M1-spectralRefineMinHz-duplicate.md |
| Gate thresholds scattered outside AnalysisConfig | `PitchPipeline.swift`, `Smoothing.swift`, `PitchDetector.swift` | Medium | ⏸ todo: docs/todos/medium-M2-gate-thresholds-outside-AnalysisConfig.md |
| No post-NSDF octave-history guard | `TunerEngine/DSP/PitchDetector.swift` | Medium | ⏸ todo: docs/todos/medium-M3-no-octave-history-guard.md |
| UserDefaults bypass in BottomDrawer | `App/Views/Monetization/BottomDrawer.swift` | Medium | ⏸ todo: docs/todos/medium-M4-userdefaults-bypass-bottomdrawer.md |
| Palette Color(hue:) magic values in two views | `BottomDrawer.swift`, `SaveCardSheet.swift` | Medium | ⏸ todo: docs/todos/medium-M5-palette-color-hue-magic-values.md |
| System fonts in monetization screens | multiple monetization views | Medium | ⏸ todo: docs/todos/medium-M6-system-fonts-monetization-screens.md |
| DispatchQueue.main.async in @MainActor view | `App/Views/Monetization/BottomDrawer.swift` | Medium | ⏸ todo: docs/todos/medium-M7-dispatchqueue-main-async.md |
| swiftui.md "no networking" rule stale | `docs/rules/swiftui.md` | Medium | ⏸ todo: docs/todos/medium-M8-swiftui-rule-networking-stale.md |
| StringRow.activeIdx dead no-op write | `LumaDesignSystem/Components/StringRow.swift` | Medium | ⏸ todo: docs/todos/medium-M9-stringrow-activeidx-dead-write.md |
| MetalStrobe no Metal path for Radial | `LumaDesignSystem/Strobe/StrobeField.swift` | Medium | ⏸ todo: docs/todos/medium-M10-metal-radial-parity-gap.md |
| StrobeLab uses Combine | `LumaDesignSystem/Strobe/StrobeLab.swift` | Medium | ⏸ todo: docs/todos/medium-M11-strobelab-uses-combine.md |
| useMetalRenderer silently ignored for Radial | `LumaDesignSystem/Strobe/StrobeField.swift` | Medium | ⏸ todo: docs/todos/medium-M12-usemetalrenderer-ignored-radial.md |
| Pervasive XCTest in 16 of 19 test files | `TunerEngine/Tests/` | Medium | ⏸ todo: docs/todos/medium-M13-xctest-migration.md |
| PitchDetectorTests copy-paste, needs parameterization | `TunerEngineTests/PitchDetectorTests.swift` | Medium | ⏸ todo: docs/todos/medium-M14-pitchdetectortests-parameterization.md |
| PipelineTests tolerances 12–40× loose | `TunerEngineTests/PipelineTests.swift` | Medium | ⏸ todo: docs/todos/medium-M15-pipelinetests-tolerances-loose.md |
| No low-B octave-safety test under stress in swift test | `TunerEngine/Tests/` | Medium | ⏸ todo: docs/todos/medium-M16-no-lowB-octave-stress-test.md |
| StimulusTests bypasses full pipeline | `TunerEngineTests/StimulusTests.swift` | Medium | ⏸ todo: docs/todos/medium-M17-stimulustests-bypasses-pipeline.md |
| Networking without CLAUDE.md annotation | `App/Networking/LumaAPI.swift` | Medium | ⏸ todo: docs/todos/medium-M18-networking-claudemd-annotation.md |
| Autocorrelation prefix-energy scalar loop | `TunerEngine/DSP/Autocorrelation.swift` | Low | ⏸ todo: docs/todos/low-L1-autocorrelation-scalar-loop.md |
| PhaseIntegrator.lsSlope scalar loops | `TunerEngine/DSP/PhaseIntegrator.swift` | Low | ⏸ todo: docs/todos/low-L2-phaseintegrator-lsslope-scalar-loops.md |
| recent() circular-buffer scalar copy | `TunerEngine/Pipeline/PitchPipeline.swift` | Low | ⏸ todo: docs/todos/low-L3-recent-scalar-copy.md |
| LumaConfig URL force-unwrap | `App/Networking/LumaConfig.swift` | Low | ⏸ todo: docs/todos/low-L4-lumaconfig-url-force-unwrap.md |
| StrobeRenderer.configure() clearColor double-write | `LumaDesignSystem/Strobe/MetalStrobe.swift` | Low | ⏸ todo: docs/todos/low-L5-stroberenderer-clearcolor-double-write.md |
| AuroraStrobe.wrappedDelta wrong home | `LumaDesignSystem/Strobe/RadialStrobe.swift` | Low | ⏸ todo: docs/todos/low-L6-wrappeddelta-wrong-home.md |
| FixturesTests UUID temp path | `TunerEngineTests/FixturesTests.swift` | Low | ⏸ todo: docs/todos/low-L7-fixturestests-uuid-temp-path.md |

---

## 2026-06-12 — full (automated, 5 agents)

| Finding | File | Severity | Status |
|---------|------|----------|--------|
| Bass lock never fires — 0.9 confidence gate unreachable for low strings | `App/Engine/LiveTunerModel.swift` | High | ✅ verified |
| Confirmation ping fires rapidly near lock boundary — no hysteresis | `App/Engine/LiveTunerModel.swift` | High | ✅ verified |
| `ToneGenerator.start()` reconfigures live `AVAudioSession` mid-capture | `App/Engine/ToneGenerator.swift` | High | ✅ verified |
| Confirmation-ping logic has no test coverage | `App/Engine/LiveTunerModel.swift` | High | ⏸ seam extracted; test target pending (see docs/todos/H4) |
| `ReducedGauge` not palette-threaded | `LumaDesignSystem/Strobe/ReducedGauge.swift` | Medium | ⏸ open |
| Lock bloom color diverges from all other lock affordances under non-default palettes | `LumaDesignSystem/Strobe/AuroraStrobe.swift` | Medium | ⏸ open |
| `minLockConfidence` hardcoded in two unlinked places | `App/Engine/LiveTunerModel.swift` | Medium | ⏸ open |
| `LumaPalette` AppStorage round-trip untested | `LumaDesignSystem/Tests/` | Medium | ⏸ open |
| Unused `import TunerEngine` in app views (pre-existing) | `App/LiveTunerScreen.swift` | Medium | ⏸ open |
| `hapticsEnabled` and `a4` stored in model not `@AppStorage` (pre-existing) | `App/Engine/LiveTunerModel.swift` | Medium | ⏸ open |
| Hardcoded band-transition hysteresis in `nextConfig` (pre-existing) | `TunerEngine/Pipeline/PitchPipeline.swift` | Medium | ⏸ open |
| `StrobePhase.bin` uses per-sample cos/sin — no vDSP (pre-existing) | `TunerEngine/DSP/StrobePhase.swift` | Medium | ⏸ open |
| `applyHann` inner loop not using vDSP multiply (pre-existing) | `TunerEngine/Pipeline/PitchPipeline.swift` | Medium | ⏸ open |
| Spring animation keys only on `active`, not `locked` | `LumaDesignSystem/Components/StringRow.swift` | Low | ⏸ open |
| `StrobeLab` palette picker missing `pickerStyle` | `LumaDesignSystem/Strobe/StrobeLab.swift` | Low | ⏸ open |
| `MetalStrobe.configure(_:)` ignores palette for `MTKView.clearColor` | `LumaDesignSystem/Strobe/MetalStrobe.swift` | Low | ⏸ open |
| `PitchReading.isLocked` default `lockCents` not linked to `LumaMusic.lockCents` (pre-existing) | `TunerEngine/PitchReading.swift` | Low | ⏸ open |

---

## 2026-06-14 — pre-launch (automated, 4 agents)

| Finding | File | Severity | Status |
|---------|------|----------|--------|
| `DEVELOPMENT_TEAM` not set — code signing blocked | `project.yml` | High | ✅ verified (3442937R38, 2026-06-14) |
| `MARKETING_VERSION: "0.1.0"` — needs v1.0.0 for App Store | `project.yml` | High | ✅ verified (1.0.0, 2026-06-14) |
| Missing `PrivacyInfo.xcprivacy` — ITMS-91053 rejection risk | `App/PrivacyInfo.xcprivacy` | High | ✅ verified (created + wired as resource, 2026-06-14) |
| Bass never locks in chromatic mode — prior fix incomplete (lock-mode only) | `App/Engine/PitchReadingStrobe.swift`, `App/Engine/LiveTunerModel.swift` | High | ✅ verified (frequency-adaptive minConf in strobeInput(); si.locked drives handleLock, 2026-06-14) |
| Lock state desync — `TunerVisualState` cents-only vs confidence-gated `strobeInput.locked` | `LumaDesignSystem/Model/TunerVisualState.swift` + all callers | High | ✅ verified (locked: Bool param added; all live screens thread strobeInput.locked; tests updated, 2026-06-14) |
| On-device verification incomplete (mic deep-link, signed mac build, tone-while-listening) | `todos/on-device-verification.md` | High | ⏸ open |
| Confirmation-ping / `LockGate` no test coverage — no `LUMATests` target | `App/Engine/LockGate.swift` | High | ⏸ open (H4 carried forward) |
| Audio session lifecycle entirely untested | `TunerEngine/TunerEngine.swift`, `Capture/AudioCapture.swift` | High | ⏸ open |
| Stale `strobeInput` persists through silence — bloom lingers on idle | `App/Engine/LiveTunerModel.swift` lines 239–248 | Medium | ⏸ open |
| Default SwiftUI Canvas render path allocates per-frame at 120fps | `LumaDesignSystem/Strobe/AuroraStrobe.swift`, `RadialStrobe.swift` | Medium | ⏸ open |
| `ReducedGauge` receives no idle signal — silence invisible under Reduce Motion | `LumaDesignSystem/Strobe/StrobeField.swift` line 42 | Medium | ⏸ open |
| `SustainGate.stable` computed and immediately discarded | `TunerEngine/Pipeline/PitchPipeline.swift` line 173 | Medium | ⏸ open |
| No App Store category (`LSApplicationCategoryType`) in Info.plist | `App/Info.plist` | Medium | ⏸ open |
| `LumaPalette` AppStorage round-trip untested | `LumaDesignSystem/Tests/` | Medium | ⏸ open (M4 carried forward) |
| `StrobeInput` conversion path (`PitchReadingStrobe`) untested | `App/Engine/PitchReadingStrobe.swift` | Medium | ⏸ open |
| `PipelineTests` tolerances 13–200× looser than published spec | `TunerEngine/Tests/TunerEngineTests/PipelineTests.swift` | Medium | ⏸ open |
| `import TunerEngine` in app views (pre-existing) | `App/LiveTunerScreen.swift`, `App/SettingsView.swift` | Medium | ⏸ open (M5 carried forward) |
| Phase-vocoder/strobe phase decoupled — contradicts `docs/rules/dsp.md` (doc gap) | `TunerEngine/Pipeline/PitchPipeline.swift`, `docs/rules/dsp.md` | Medium | ⏸ open |
| Force-unwraps in DSP production paths (CLAUDE.md violation) | `DSP/PitchDetector.swift` line 93, `DSP/Autocorrelation.swift` line 61, `DSP/HarmonicEstimator.swift` line 98 | Low | ⏸ open |
| NSDF k = 0.90 vs. McLeod cited 0.93 | `DSP/PitchDetector.swift` line 91 | Low | ⏸ open |
| Metal shader compiled at runtime — silent failure on shader error | `LumaDesignSystem/Strobe/MetalStrobe.swift` lines 151–167 | Low | ⏸ open |
| `TunerSimulator` always emits `phase: 0` — phaseScroll untestable in StrobeLab | `LumaDesignSystem/Strobe/TunerSimulator.swift` line 39 | Low | ⏸ open |
| `.shadow()` direct usage outside `.bloom()` in 3 components | `Components/Brand.swift`, `Components/InputSource.swift`, `Components/StringRow.swift` | Low | ⏸ open |
| Magic numbers in component layout (bypass `Space.*`/`Radius.*` tokens) | multiple `Components/` files | Low | ⏸ open |

---

## 2026-06-10 — engine-audit (manual)

| Finding | File | Severity | Status |
|---------|------|----------|--------|
| CRLB constant 2× too small | `Bench/BenchmarkSuite.swift` | High | ✅ verified |
| Stop→start killed readings stream permanently | `TunerEngine/TunerEngine.swift` | Critical | ✅ verified |
| `Diagnosis.probeB` ignored `centerBin` | `Bench/` | High | ✅ verified |
| WAV decoder accepted unsupported formats as silence | `TunerEngine/Capture/` | High | ✅ verified |
| Audio session ownership not managed by app layer (iOS) | `LUMA/App/Engine/` | Medium | ⏸ open |
| Route-change/interruption not handled | `TunerEngine/Capture/` | Medium | ⏸ open |
| Input-preference logic (BT mic) | `TunerEngine/Capture/` | Medium | ⏸ open |
| macOS entitlements not verified in CI | `LUMA.entitlements` | Medium | ⏸ open |
| App/engine glue serialization (concurrent calls) | `App/Engine/LiveTunerModel.swift` | Medium | ⏸ open |
| Tone generator node not detached on stop | `App/Engine/` | Medium | ⏸ open |
| Haptics threading (called off main thread) | `App/Engine/` | Medium | ⏸ open |
| Ring buffer allocation on first call | `TunerEngine/Pipeline/` | Low | ⏸ open |
