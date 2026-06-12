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

## Step 7a — Adversarial verify before writing

Before writing the solution file, dispatch the domain-appropriate specialist agent to validate the finding:

| Domain(s) from Step 1 | Agent to consult |
|-----------------------|-----------------|
| `dsp`, `pipeline`, `capture` | `dsp-specialist` |
| `strobe` | `strobe-specialist` |
| `swiftui`, `design-system` | `swiftui-specialist` |
| `testing` | `testing-specialist` |

Ask the agent: "Is this finding genuine and non-obvious? Is the proposed solution correct? Is there a simpler explanation or existing pattern that already handles this?"

If the agent refutes the finding → skip writing the solution file. The finding is either obvious from the code, already covered by a rules file, or the fix is wrong.

If the agent confirms → proceed.

## Step 7b — Overlap check against existing solutions

Before writing a new solution file:

```bash
grep -r "tags:" docs/solutions/ | grep "<domain>"
```

Also scan by symptom or title similarity. If a solution with ≥2 matching tags and a similar `applies_to` glob already exists → update that file instead of creating a duplicate. Add a `## YYYY-MM-DD update` section to the existing file.

## Step 7c — Update agent files if a domain pattern changed

If the finding reveals a new constraint that every future reviewer of this domain should know:
- Append a terse note to the relevant specialist agent in `.claude/agents/<domain>-specialist.md`
- Add it to the review checklist section

Only do this for structural patterns (algorithm constraints, API behaviors, invariants), not for bug fixes specific to one file.

## Step 7d — Commit

```bash
git add docs/solutions/ docs/rules/ docs/LEARNINGS.md
git commit -m "docs(solutions): <short description of what was codified>"
```
