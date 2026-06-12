# /audit — Structured Code Audit

Run a structured audit of LUMA code. Dispatches domain specialist agents in parallel, collects findings, deduplicates against prior audits, and serializes to `docs/audits/`.

## Usage

```
/audit [scope]
```

Scopes: `dsp` | `strobe` | `ui` | `testing` | `accuracy` | `pre-launch` | `full` (default)

## Step 1 — Determine scope and agent dispatch

| Scope | Agents dispatched |
|-------|-------------------|
| `dsp` | dsp-specialist |
| `strobe` | strobe-specialist |
| `ui` | swiftui-specialist |
| `testing` | testing-specialist |
| `accuracy` | dsp-specialist + testing-specialist |
| `pre-launch` | dsp-specialist + strobe-specialist + swiftui-specialist + testing-specialist |
| `full` | all 4 specialists + code-reviewer (cross-cutting) |

If no scope is provided, default to `full`.

## Step 2 — Brief each agent

Before dispatching, prepare each agent's brief:
- The scope of the audit
- Which files/packages to review (see file map below)
- Instruction to read the relevant `docs/rules/<domain>.md` file first
- Instruction to check `docs/solutions/` for known patterns that should be applied
- **Discovery only** — report findings, do not fix anything in this phase

**File scope by domain:**
```
dsp-specialist    → Packages/TunerEngine/Sources/TunerEngine/DSP/
                    Packages/TunerEngine/Sources/TunerEngine/PitchReading.swift
                    Packages/TunerEngine/Sources/TunerEngine/Pipeline/PitchPipeline.swift
                    Packages/TunerEngine/Sources/TunerEngine/AnalysisConfig.swift

strobe-specialist → Packages/LumaDesignSystem/Sources/LumaDesignSystem/Strobe/
                    (any *.metal files)

swiftui-specialist → LUMA/App/*.swift
                     LUMA/App/Engine/LiveTunerModel.swift
                     Packages/LumaDesignSystem/Sources/LumaDesignSystem/Components/
                     Packages/LumaDesignSystem/Sources/LumaDesignSystem/Tokens/

testing-specialist → Packages/TunerEngine/Tests/
                     Packages/LumaDesignSystem/Tests/
                     Packages/TunerEngine/Bench/
```

## Step 3 — Run agents in parallel

Dispatch all agents for the scope simultaneously. Each agent:
1. Reads its domain rules file (`docs/rules/<domain>.md`)
2. Scans relevant solution files in `docs/solutions/` for known patterns
3. Reviews the target files
4. Returns structured findings using the output format from its agent definition

**Collect all findings before proceeding.**

## Step 4 — Deduplicate against CHANGELOG

Read `docs/audits/CHANGELOG.md`. For each finding:
- Check if a finding with the same file + issue description was already addressed in a prior audit
- If found in CHANGELOG as **verified** → skip (already fixed)
- If found as **open** → carry forward (still unresolved)
- If new → mark as **new**

Only proceed with new + carried-forward findings.

## Step 5 — Serialize findings to audit file

Create `docs/audits/YYYY-MM-DD-<scope>.md` using today's date:

```markdown
---
scope: <scope>
date: YYYY-MM-DD
status: open
agent_count: N
finding_count: N
---

# LUMA Audit — <Scope> — YYYY-MM-DD

## Summary
- Agents run: N
- Total findings: N (Critical: X, High: Y, Medium: Z, Low: W)
- New findings: N
- Carried forward: N

## Critical Findings
[findings at Critical severity]

## High Findings
[findings at High severity]

## Medium Findings
[findings at Medium severity]

## Low Findings
[findings at Low severity]

## Verification Log
[populated as findings are fixed and verified — see Step 7]
```

Present a summary of findings to the user. Ask: "Shall I fix the Critical and High findings now, or would you like to review first?"

## Step 6 — Fix findings (with user approval)

For each Critical/High finding (in order):
1. Make the minimal fix required
2. Run `swift test --package-path Packages/TunerEngine` (for DSP/pipeline/testing findings)
3. Run `swift test --package-path Packages/LumaDesignSystem` (for strobe/UI findings)
4. If tests pass → mark finding as **verified** in the audit file
5. If tests fail → stop and surface the failure; do not mark verified

Do not fix Medium/Low findings unless the user asks. Surface them as a deferred list.

## Step 7 — Update CHANGELOG

After all verified fixes, append to `docs/audits/CHANGELOG.md`:

```markdown
## YYYY-MM-DD — <Scope>

| Finding | File | Severity | Status |
|---------|------|----------|--------|
| <title> | `path/file.swift` | Critical | ✅ verified |
| <title> | `path/file.swift` | High | ✅ verified |
| <title> | `path/file.swift` | Medium | ⏸ deferred |
```

## Step 8 — Prompt for codification

If any High or Critical finding was fixed and verified:
```
Findings verified. Recommend running /codify to preserve the fix patterns in docs/solutions/
so they auto-inject on future edits to these files.
```
