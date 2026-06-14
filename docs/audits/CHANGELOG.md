# Audit CHANGELOG

Deduplication index for all findings surfaced across audit runs. Before adding a finding to a new audit, check here to avoid re-surfacing already-verified issues.

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
