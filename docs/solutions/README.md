# Solutions

Accumulated patterns and bug-tracks from development. Written via `/codify` after implementation work or code review. Auto-surfaced as references by `inject-patterns.sh` when editing files in the tagged domain.

## Categories

| Category | Contents |
|----------|----------|
| `runtime-errors/` | Crashes, unexpected nil, actor isolation violations, audio thread faults |
| `logic-errors/` | Wrong output that compiled — off-by-one, sign errors, incorrect DSP formulas, phase math bugs |
| `code-quality/` | Refactoring patterns, naming, type safety, Swift idiom improvements |
| `performance-issues/` | Measured regressions: DSP throughput, Metal render jank, memory |
| `conventions/` | Project-specific invariants and why they exist |
| `design-patterns/` | Reusable architectural patterns for this codebase |
| `best-practices/` | Proven approaches for Accelerate, Metal, AVAudioEngine, SwiftUI in this codebase |

## File naming

`docs/solutions/<category>/<slug>-YYYY-MM-DD.md`

Example: `docs/solutions/logic-errors/nsdf-peak-selection-octave-error-2026-06-09.md`

## Frontmatter schema

```yaml
---
title: "Short imperative description — what the rule or finding is"
track: knowledge | bug
category: runtime-errors | logic-errors | code-quality | performance-issues | conventions | design-patterns | best-practices
tags: [dsp, capture, pipeline, strobe, swiftui, design-system, testing]
module: TunerEngine | LumaDesignSystem | App
applies_to: ["Packages/TunerEngine/Sources/TunerEngine/DSP/*.swift"]
created: YYYY-MM-DD
---
```
