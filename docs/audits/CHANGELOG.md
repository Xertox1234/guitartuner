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
