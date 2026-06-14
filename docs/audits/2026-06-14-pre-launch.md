---
scope: pre-launch
date: 2026-06-14
status: open
agent_count: 4
finding_count: 21
---

# LUMA Audit — Pre-Launch — 2026-06-14

## Summary
- Agents run: 4 (dsp-specialist, strobe-specialist, swiftui-specialist, testing-specialist)
- Total findings: 21 (Critical: 0, High: 8, Medium: 10, Low: 6, Info: 1)
- New findings: 16
- Carried forward from prior audits: 5 (H4, M3, M4, M5, audio-session cluster)
- Prior findings confirmed fixed: all 4 Critical/High from 2026-06-12 remain verified

---

## Hard Submission Blockers

These three prevent App Store submission regardless of code quality.

### [S1] DEVELOPMENT_TEAM Not Set
**Severity:** High | **File:** `project.yml` line 21
`DEVELOPMENT_TEAM: ""` with a `# TODO:`. Without a team ID, no archive, no provisioning profile, no signed build. Set to your 10-character Apple Developer team ID, then `xcodegen generate`.

### [S2] Marketing Version Is 0.1.0
**Severity:** High | **File:** `project.yml` lines 17–18
App releases at v0.1.0 sends the wrong signal for a paid $9.95 product. Set `MARKETING_VERSION: "1.0.0"`. Also decide how `CURRENT_PROJECT_VERSION` increments (monotonically per TestFlight upload).

### [S3] Missing PrivacyInfo.xcprivacy — ITMS-91053 Risk ⚠️ NEW
**Severity:** High | **File:** Not yet present; needs `App/PrivacyInfo.xcprivacy`
`@AppStorage` (used in `LiveTunerScreen`, `SettingsView`, `MenuBarTuner`, `RootView`) is backed by `UserDefaults`, classified as a Required-Reason API (`NSPrivacyAccessedAPICategoryUserDefaults`). Since May 2024, submitting without a manifest declaration triggers automated ITMS-91053 rejection. **This is not tracked anywhere in the project's todos or roadmap — it's the most important new finding.**

Required manifest content:
```xml
<key>NSPrivacyTracking</key><false/>
<key>NSPrivacyCollectedDataTypes</key><array/>
<key>NSPrivacyAccessedAPITypes</key>
<array>
  <dict>
    <key>NSPrivacyAccessedAPIType</key>
    <string>NSPrivacyAccessedAPICategoryUserDefaults</string>
    <key>NSPrivacyAccessedAPITypeReasons</key>
    <array><string>CA92.1</string></array>
  </dict>
</array>
```
Wire into `project.yml` as a resource in the LUMA target.

---

## High Findings

### [H1] Bass Never Locks in Chromatic Mode — Prior Fix Was Incomplete
**Severity:** High | **Files:** `App/Engine/LiveTunerModel.swift` line 223, `App/Engine/PitchReadingStrobe.swift` line 16
The 2026-06-12 audit fixed bass locking in **lock-mode** (`LiveTunerModel` lines 206–207: `let minConf = r.frequency < 120 ? 0.75 : 0.9`). But in **chromatic mode** (the default for new users), both the `LiveTunerModel.apply` chromatic path (line 223) and `PitchReadingStrobe.strobeInput` (line 16) call `r.isLocked(lockCents: LumaMusic.lockCents)` with no `minConfidence` override — falling back to the default `0.9`. The documented bass clarity ceiling is ~0.85, so bass strings E2, A2, D2, and all 5-string notes never lock in chromatic mode. The strobe freeze and lock haptic never fire for bass in the default mode.

**Fix:** Either pass `minConfidence: r.frequency < 120 ? 0.75 : 0.9` at both chromatic-mode call sites, or move the per-frequency floor into `isLocked` itself as the single source of truth.

### [H2] Lock State Desync — UI Shows "IN TUNE" While Strobe Doesn't Bloom
**Severity:** High | **Files:** `App/Engine/LiveTunerModel.swift` lines 207/213/222–223, `LumaDesignSystem/Model/TunerVisualState.swift` lines 47–50
`TunerVisualState.from(cents:)` — which drives the note glow, "IN TUNE" pill, mint accent, and `NoteReadout(locked:)` — is **cents-only** with no confidence gate. The strobe bloom and haptic are gated on both cents AND confidence (`strobeInput.locked`). During note decay (confidence drops below 0.75–0.9, pitch still near zero): `TunerVisualState` returns `.tune` (mint UI, "IN TUNE" pill) while `strobeInput.locked = false` (no bloom, no haptic). The readouts celebrate; the strobe and haptic don't trigger. Also works in reverse: strobe can show locked when readout is flat/sharp.

**Fix:** Derive `TunerVisualState` from `strobeInput.locked` rather than independently from cents. One source of truth should drive all lock affordances.

### [H3] On-Device Verification Incomplete
**Severity:** High | **File:** `todos/on-device-verification.md`
Three items with direct App Store risk:
1. **Mic permission deep-link** — the `permissionDenied` "Open Settings" URL is documented as macOS-version-fragile (`docs/solutions/mic-permission-denied-settings-deeplink-2026-06-12.md`); unverified on current macOS.
2. **Signed sandboxed macOS mic access** — the `audio-input` entitlement exists but has not been verified with a signed sandboxed build (`docs/solutions/macos-audio-input-entitlement-2026-06-12.md` documents the silent failure mode).
3. **Tone-while-listening on iOS** — H3 fix (`ToneGenerator.prepare()` before `engine.start()`) is in code but has no real-device confirmation pass.

### [H4] No LockGate or LiveTunerModel Tests — App Test Target Missing *(carried forward)*
**Severity:** High | **Files:** `App/Engine/LockGate.swift`, `App/Engine/LiveTunerModel.swift`, `project.yml`
`LockGate` is a pure injectable struct; five behaviors (rising-edge haptic, consecutive-lock suppression, ping cooldown, cooldown expiry, `reset()` re-arms) are entirely uncovered. `LiveTunerModel.apply()` per-band confidence dispatch and watchdog also untested. No `LUMATests` target in `project.yml`.

**Fix:** Add `LUMATests` target to `project.yml`; write `LockGateTests.swift` (the five behaviors). See H4 in `docs/todos/H4`.

### [H5] Audio Session Lifecycle Entirely Untested
**Severity:** High | **Files:** `TunerEngine/Capture/AudioCapture.swift`, `TunerEngine/TunerEngine.swift`
`TunerEngine` actor start/stop/restart, `AudioCapture` iOS session config (`.measurement` mode, DI detection), error paths, and `@unchecked Sendable` + manual `running` bool concurrency are all untested. A stop/restart race on iOS is the highest-probability crash path.

---

## Medium Findings

### [M1] Stale StrobeInput Persists Through Silence — Bloom Lingers on Idle
**Severity:** Medium | **File:** `App/Engine/LiveTunerModel.swift` lines 239–248
The watchdog that fires after 350 ms silence nulls `cents` and resets `lockGate` but does **not** reset `strobeInput`. If last reading was locked, `strobeInput.locked = true` persists indefinitely — strobe blooms while UI shows idle.

**Fix:** In watchdog, also reset `strobeInput = StrobeInput()` (default: `cents: 0, phase: 0, locked: false`).

### [M2] Default Render Path Allocates Per-Frame at 120fps
**Severity:** Medium | **Files:** `LumaDesignSystem/Strobe/AuroraStrobe.swift` lines 113–132, `RadialStrobe.swift` lines 119–137
`useMetalStrobe = false` is the default in `LiveTunerScreen` (line 28). The SwiftUI Canvas path allocates `Gradient` + `Path` per ribbon per frame (13 ribbons for Aurora, 36 marks for Radial) at 120fps. The Metal renderer is already allocation-free and production-correct. Profile with Instruments on a ProMotion device before launch to determine if frame pacing is affected.

### [M3] ReducedGauge Receives No Idle Signal — Silence Invisible Under Reduce Motion
**Severity:** Medium | **File:** `LumaDesignSystem/Strobe/StrobeField.swift` line 42
`StrobeField` passes `input.cents` and `input.locked` to `ReducedGauge` but omits `idle`. Under Reduce Motion, silence leaves the needle/arc at the last-known position with normal styling — no breathing or zeroing behavior. `AuroraStrobe` and `RadialStrobe` both receive `idle` and respond; `ReducedGauge` doesn't.

**Fix:** Add `idle: Bool` parameter to `ReducedGauge`; pass `idle: idle` from `StrobeField`.

### [M4] SustainGate.stable Computed and Immediately Discarded
**Severity:** Medium | **File:** `TunerEngine/Pipeline/PitchPipeline.swift` line 173
`SustainGate.step` returns `(emit: Bool, stable: Bool)`. `stable` is silently discarded with `let (emit, _) = gate.step(...)`. The strobe could theoretically enter freeze animation on the first high-confidence pluck frame before sustained lock is confirmed.

### [M5] No App Store Category in Info.plist
**Severity:** Medium | **File:** `App/Info.plist`
No `LSApplicationCategoryType` key. Required for macOS App Store listing under a category.
**Fix:** Add `<key>LSApplicationCategoryType</key><string>public.app-category.music</string>` to `App/Info.plist`. Silently ignored on iOS.

### [M6] LumaPalette AppStorage Round-Trip Untested *(carried forward from M4)*
**Severity:** Medium | **File:** `LumaDesignSystem/Tests/LumaDesignSystemTests/LumaPaletteTests.swift`
Raw-value round-trip (`LumaPalette(rawValue: p.rawValue) == p`) not asserted. `StrobeStyleTests` provides the working pattern.

### [M7] StrobeInput Conversion Path Untested
**Severity:** Medium | **File:** `App/Engine/PitchReadingStrobe.swift`
`PitchReading.strobeInput()` — the seam between engine output and Metal renderer — has no test. A silent drift in `lockCents` constants between `LumaMusic` and `PitchReading.isLocked` would produce split lock states with no CI signal.

### [M8] PipelineTests Tolerances 13–200× Looser Than Published Spec
**Severity:** Medium | **File:** `TunerEngine/Tests/TunerEngineTests/PipelineTests.swift` lines 31–101
`testTracksCleanGuitarNote` allows ±3¢ (published mean: 0.23¢, headroom: 13×). `testNoiseRobustness` allows ±50¢. A significant accuracy regression passes `swift test` and is only caught by the full benchmark run.

### [M9] `import TunerEngine` in App Views *(carried forward)*
**Severity:** Medium | **Files:** `App/LiveTunerScreen.swift` line 3, `App/SettingsView.swift` line 3
Neither file uses any `TunerEngine` symbol. Package boundary violation per architecture rules.

### [M10] Phase-Vocoder / Strobe Phase Decoupled from DSP Rules Doc
**Severity:** Medium | **File:** `TunerEngine/Pipeline/PitchPipeline.swift` lines 136–169, `docs/rules/dsp.md`
`docs/rules/dsp.md` states strobe phase and phase advance "must not be decoupled." Current code uses separate computation paths (absolute DFT phase for strobe, inter-hop for frequency refinement). Accuracy spec is met — the divergence is a maintenance trap, not a current regression. Either update the rule or annotate the code.

---

## Low Findings

### [L1] Force-Unwraps in Production Paths (CLAUDE.md Violation)
**Severity:** Low | **Files:** `DSP/PitchDetector.swift` line 93, `DSP/Autocorrelation.swift` line 61, `DSP/HarmonicEstimator.swift` line 98
All three are provably safe given upstream guards, but CLAUDE.md prohibits force-unwrapping in production code paths. Replace with `guard let` / `?? fallback`.

### [L2] NSDF k = 0.90 vs. McLeod Cited 0.93
**Severity:** Low | **File:** `DSP/PitchDetector.swift` line 91
Paper cites 0.93; code uses 0.90. Benchmark shows 0.00% octave errors — not a regression. Either raise to 0.93 and re-validate, or update comment to document intentional tuning.

### [L3] Metal Shader Compiled at Runtime — Silent Failure
**Severity:** Low | **File:** `LumaDesignSystem/Strobe/MetalStrobe.swift` lines 151–167
Shader compile errors produce `nil` renderer with no log output. A refactor regression would produce a blank Metal view with no developer signal. At minimum log the error; ideally add a CI step compiling the MSL source.

### [L4] TunerSimulator Always Emits phase: 0 — phaseScroll Untestable in StrobeLab
**Severity:** Low | **File:** `LumaDesignSystem/Strobe/TunerSimulator.swift` line 39
Phase hardcoded to 0. Add a comment documenting the limitation, or add a synthetic phase accumulator to enable lab testing of the scroll path.

### [L5] `.shadow()` Direct Usage Outside `.bloom()` in 3 Components
**Severity:** Low | **Files:** `Components/Brand.swift` line 43, `Components/InputSource.swift` line 27, `Components/StringRow.swift` line 84
Design system rule: glow via `.bloom()` only. These three direct `.shadow()` calls bypass the centralized bloom system and won't respond to future bloom tuning.

### [L6] Magic Numbers in Component Layout
**Severity:** Low | **Files:** `Components/TargetChip.swift`, `Components/Brand.swift`, `Components/StringRow.swift`, `Components/InputSource.swift`
Multiple raw `padding`, `spacing`, `cornerRadius`, and font-size numbers bypass `Space.*` / `Radius.*` design tokens. No launch risk — flag for next design-system pass.

---

## Informational

### [I1] Benchmark CI Gate Confirmed — Thresholds Intentionally Loose
**Source:** testing-specialist
Gate thresholds in `main.swift` are looser than the published spec in `accuracy.md` (1.2¢ gate vs 0.23¢ actual). This is intentional headroom per Plan 06. The published report is the spec; CI catches regressions, not compliance. P2/P3 gate tightening commented out as TODOs — correct per plan.

---

## Launch Completeness Assessment

### Hard Blockers (submission impossible)
| Item | Status |
|------|--------|
| `DEVELOPMENT_TEAM` in `project.yml` | ❌ Open |
| `MARKETING_VERSION` = 1.0.0 | ❌ Open (currently 0.1.0) |
| `PrivacyInfo.xcprivacy` manifest | ❌ Open (not tracked anywhere) |
| App Store Connect metadata + screenshots | ❌ Open (`todos/release-readiness.md`) |
| TestFlight real-device pass | ❌ Open (`todos/on-device-verification.md`) |

### Quality Gaps (should close before v1)
| Item | Status |
|------|--------|
| Bass strings don't lock in chromatic mode (H1) | ❌ Open |
| Lock state desync — UI vs strobe (H2) | ❌ Open |
| Stale strobeInput on idle (M1) | ❌ Open |
| ReducedGauge has no idle state (M3) | ❌ Open |
| App Store category in Info.plist (M5) | ❌ Open |
| No `LUMATests` target (H4) | ❌ Open (deferred) |
| `hapticsEnabled` / `a4` not persisted | ❌ Open (known) |
| Audio interruption / route-change | ❌ Open (known) |
| Localization decision | ❌ Open (`todos/ux-follow-ups.md`) |

### Done — v1-Ready
| Item | Status |
|------|--------|
| TunerEngine DSP: 0.23¢ mean, 0% octave errors, CI-gated | ✅ |
| Both strobe renderers (Aurora Canvas + Radial) + Metal opt-in | ✅ |
| Stage Mode (ZStack overlay, screen-wake iOS) | ✅ |
| macOS menu-bar micro-strobe | ✅ |
| Settings sheet with display preference persistence | ✅ |
| App icon: iOS 1024 + all macOS sizes | ✅ |
| Bundled fonts (Chakra Petch, JetBrains Mono) | ✅ |
| `NSMicrophoneUsageDescription` in Info.plist | ✅ |
| `LUMA.entitlements` with audio-input entitlement | ✅ |
| `ITSAppUsesNonExemptEncryption: false` | ✅ |
| `ENABLE_HARDENED_RUNTIME: YES` | ✅ |
| Privacy-by-architecture (no networking, no analytics) | ✅ |
| Cold open into breathing strobe (no splash on release) | ✅ |
| Accuracy benchmark infrastructure, CI-gated | ✅ |

---

## Verification Log

*(populated as findings are fixed and verified)*
