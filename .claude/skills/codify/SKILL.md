# /codify — Codify patterns and learnings

Run this after implementing something non-obvious, fixing a subtle bug, or completing a code review. Extract what was learned and write it into `docs/solutions/` so future sessions automatically get it injected.

## When to run

- After fixing a bug that wasn't obvious from the code
- After an architectural decision with non-obvious tradeoffs (why TunerEngine stays UI-free, why ToneSynth is phase-continuous, etc.)
- After discovering a DSP constraint, Metal limitation, AVAudioEngine gotcha, or SwiftUI quirk specific to this codebase
- After any session that produced "I should remember this" moments

## Step 1 — Classify changed paths into domains

```bash
git diff --name-only HEAD~1  # or your relevant range
```

| Path pattern | Domain |
|---|---|
| `TunerEngine/DSP/`, `*Autocorrelation*`, `*PitchDetector*`, `Note.swift`, `PitchReading*`, `Bench/` | `dsp` |
| `TunerEngine/Capture/`, `*AudioCapture*`, `*MicrophonePermission*` | `capture` |
| `TunerEngine/Pipeline/`, `*RingBuffer*`, `*PitchPipeline*`, `TunerEngine.swift`, `*ToneSynth*` | `pipeline` |
| `LumaDesignSystem/Strobe/`, `*Strobe*`, `*StrobeField*`, `*StrobeInput*`, `*ReducedGauge*` | `strobe` |
| `App/*.swift`, `App/Engine/`, `*LiveTunerScreen*`, `*LiveTunerModel*`, `*SettingsView*` | `swiftui` |
| `LumaDesignSystem/Tokens/`, `LumaDesignSystem/Components/`, `*LumaColor*`, `*LumaFont*`, `*Modifiers/*` | `design-system` |
| `*Tests/`, `*Tests.swift` | `testing` |

## Step 2 — Apply the codification filter

**Write a solution file if any of these are true:**
- A bug that took >15 minutes to diagnose
- A constraint not obvious from reading the code (audio thread rules, phase continuity, window sizing rationale)
- A pattern you'd want injected automatically on future edits in this domain
- An architectural invariant that must not be broken (TunerEngine UI-free, LumaDesignSystem DSP-free)
- A measurement or benchmark finding that anchors a decision

**Skip if:**
- The change is obvious from reading the code or standard Swift/Apple docs
- It's purely mechanical (rename, format, file move)
- It's already in `docs/rules/<domain>.md` — update that file instead

## Step 3 — Route by finding nature

| Nature | Category | Track |
|--------|----------|-------|
| Crash, unexpected nil, actor isolation violation, audio thread fault | `runtime-errors/` | bug |
| Wrong DSP output, phase math error, off-by-one in window sizing, incorrect formula | `logic-errors/` | bug |
| Naming, type safety, Swift idiom, simplification | `code-quality/` | knowledge |
| DSP throughput regression, Metal render jank, memory spike | `performance-issues/` | bug or knowledge |
| Project-specific invariant (TunerEngine UI-free, ring buffer rules, phase continuity) | `conventions/` | knowledge |
| Architectural pattern (StrobeInput contract, pipeline/capture separation) | `design-patterns/` | knowledge |
| Proven approach for Accelerate, Metal, AVAudioEngine, SwiftUI in this codebase | `best-practices/` | knowledge |

## Step 4 — Write the solution file

Filename: `docs/solutions/<category>/<slug>-YYYY-MM-DD.md`

Slug: lowercase, hyphen-separated, describes the finding. Use today's date.

### Frontmatter

```yaml
---
title: "Short imperative description"
track: knowledge | bug
category: <category from table above>
tags: [<one or more LUMA domains>]
module: TunerEngine | LumaDesignSystem | App
applies_to: ["relative/path/to/affected/files"]
created: YYYY-MM-DD
---
```

### Body — knowledge track

```markdown
## When this applies
[What file/situation triggers this]

## The pattern
[What to do — concrete and terse]

## Why
[The non-obvious constraint: physics, API behavior, architecture invariant]

## Examples
[Before/after or code snippet if it adds clarity]

## Related files
[Files this applies to]
```

### Body — bug track

```markdown
## Symptom
[What broke and how it manifested]

## Root cause
[The actual mechanism of the bug]

## Fix
[What changed]

## Why it was wrong
[The invariant that was violated]

## Related files
[Files changed in the fix]
```

## Step 5 — Optionally update docs/rules/<domain>.md

If the finding is a short, binding directive every future edit in this domain should know — add it to the relevant `docs/rules/<domain>.md`. Keep rules files terse: the inject hook embeds them inline under a ~9KB cap. If it's detailed (code example, multi-paragraph explanation), the solution file alone is correct.

## Step 6 — Optionally update docs/LEARNINGS.md

Add a one-liner at the top:
```
- YYYY-MM-DD: [short description] → docs/solutions/<category>/<filename>.md
```

## Step 7 — Commit

```bash
git add docs/solutions/ docs/rules/ docs/LEARNINGS.md
git commit -m "docs(solutions): <short description of what was codified>"
```
