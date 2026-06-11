# LUMA — Guitar & Bass Tuner

Pro-grade, privacy-first tuner for iPhone, iPad, and Mac. Native Swift/SwiftUI multiplatform (not Catalyst), one-time $9.95. Two co-equal pillars: **accuracy** (strobe-grade DSP) and **visual experience** (Metal strobe at 120 fps). **Privacy by architecture:** on-device only, v1 collects nothing.

## Architecture

```
LUMA/App/                     SwiftUI multiplatform app + engine glue
LUMA/App/Engine/              LiveTunerModel, ToneGenerator, Haptics, PitchReadingStrobe
Packages/TunerEngine/         UI-free DSP + capture (no SwiftUI dep)
Packages/LumaDesignSystem/    Design tokens, components, strobe renderers (no DSP dep)
project.yml                   XcodeGen spec — source of truth for LUMA.xcodeproj
docs/                         DESIGN.md, EXPERIENCE.md, plans/, benchmarks/, rules/, solutions/
```

**The clean separation that must be preserved:**
- `TunerEngine` → no UI, no `LumaDesignSystem` imports; emits `PitchReading`
- `LumaDesignSystem` → no DSP, no `TunerEngine` imports; consumes `StrobeInput`
- `App/Engine/LiveTunerModel` → app-layer glue mapping `PitchReading → StrobeInput`

## Key Types

| Type | File | Role |
|------|------|------|
| `TunerEngine` | `TunerEngine/TunerEngine.swift` | `public actor` — capture + DSP, emits `AsyncStream<PitchReading>` |
| `PitchReading` | `TunerEngine/PitchReading.swift` | note, cents, confidence, phase (0…1 strobe cycle), frequency, timestamp |
| `PitchPipeline` | `TunerEngine/Pipeline/PitchPipeline.swift` | testable DSP core — push samples, get readings; no AVAudioEngine |
| `LiveTunerModel` | `App/Engine/LiveTunerModel.swift` | `@MainActor @Observable` — engine→UI bridge, owns tone/haptics/targeting |
| `StrobeInput` | `LumaDesignSystem/Strobe/StrobeInput.swift` | strobe render contract (phase, state, idle flag) |
| `StrobeField` | `LumaDesignSystem/Strobe/StrobeField.swift` | SwiftUI strobe dispatcher (Aurora/Radial/reduced gauge) |
| `AuroraStrobe` | `LumaDesignSystem/Strobe/AuroraStrobe.swift` | Metal-rendered default strobe (120 fps) |

## Build Commands

```bash
# Generate Xcode project (one-time)
brew install xcodegen && xcodegen generate && open LUMA.xcodeproj

# Test TunerEngine (no Xcode needed)
swift test --package-path Packages/TunerEngine

# Run accuracy benchmark
swift run -c release --package-path Packages/TunerEngine Benchmark --compare --out docs/benchmarks

# Test LumaDesignSystem
swift test --package-path Packages/LumaDesignSystem

# Iterate on design system via Previews
open Packages/LumaDesignSystem/Package.swift
```

## Accuracy Spec (measured, CI-gated)

| Metric | Result |
|--------|--------|
| Mean abs cents error (clean) | 0.23 ¢ |
| Mid/high range | 0.11–0.15 ¢ |
| Low bass (< 82 Hz) | 0.59 ¢ (worst case 5.81 ¢) |
| Octave-error rate | **0.00%** (207 cases incl. 5-string low B) |
| Noise robustness | ~0.5 ¢ at 10 dB SNR, 0 octave errors |
| Time-to-lock | ~43 ms median; ~100–150 ms for lowest bass strings (physics, not a bug) |

## Workflow Standards

- **Domain rules auto-inject** at edit time via `.claude/hooks/inject-patterns.sh` — rules live in `docs/rules/<domain>.md`
- **After finding something non-obvious**, run `/codify` to write it into `docs/solutions/`
- **Never break CI** — accuracy benchmark is CI-blocking; `swift test` must pass
- **Validate Swift edits** with `XcodeRefreshCodeIssuesInFile` (fast) then `BuildProject` when uncertain
- **Audio never leaves the device** — no networking in v1; do not add URLSession or any network calls
- **Swift Concurrency everywhere** — `async/await`, `actor`, `AsyncStream`; no Combine
- **No force-unwrapping** in production code paths

## Testing Strategy

- Test `PitchPipeline` headlessly — push synthesized/file samples, get readings; no audio device
- Use `TunerEngine/Bench/Stimulus.swift` for synthesized tones, `Fixtures.swift` for file fixtures
- Swift Testing framework (`@Test`, `#expect`) for new tests
- CI runs `swift test` + accuracy benchmark on every push — `docs/benchmarks/accuracy.md` is the spec

## Domains

| Domain | Files | Rules |
|--------|-------|-------|
| `dsp` | `TunerEngine/DSP/*`, `Note.swift`, `PitchReading.swift`, `Bench/` | `docs/rules/dsp.md` |
| `capture` | `TunerEngine/Capture/*` | `docs/rules/capture.md` |
| `pipeline` | `TunerEngine/Pipeline/*`, `TunerEngine.swift`, `ToneSynth.swift` | `docs/rules/pipeline.md` |
| `strobe` | `LumaDesignSystem/Strobe/*` | `docs/rules/strobe.md` |
| `swiftui` | `App/*.swift`, `App/Engine/*` | `docs/rules/swiftui.md` |
| `design-system` | `LumaDesignSystem/Tokens/*`, `Components/*`, `Model/*`, `Modifiers/*` | `docs/rules/design-system.md` |
| `testing` | `**Tests/*` | `docs/rules/testing.md` |

## Cheap-Worker Delegation (from global CLAUDE.md)

Scripts available: `ask-kimi`, `kimi-write`, `extract-chat`, `kimi-review`, `kimi-challenge`

- Reading 3+ files for analysis → `ask-kimi --paths [files] --question "..."`
- Before architectural decisions → `kimi-challenge --decision "[approach]"`
- Never delegate: DSP algorithm correctness, Metal shader safety, audio thread constraints
