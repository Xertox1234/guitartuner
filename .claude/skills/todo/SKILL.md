# /todo — Todo Orchestrator

Orchestrate a batch of implementation tasks from the LUMA backlog (ROADMAP.md or Plan 06). Five phases: cleanup, baseline, triage, plan, execute.

## Usage

```
/todo [filter]
```

Optional filter: `plan06` | `p2` | `p3` | `accuracy` | `strobe` | (none = all backlog items)

---

## Phase 0 — Cleanup

Before touching any code, verify workspace health:

```bash
# Check for stale worktrees
git worktree list

# Check current branch state
git status
git log --oneline -5

# Check CI state (if GitHub remote configured)
gh pr status 2>/dev/null || echo "no remote configured"
```

Remove dead worktrees if found:
```bash
git worktree prune
```

Report: current branch, any uncommitted changes, any stale worktrees cleaned.

---

## Phase 1 — Baseline

Establish a clean baseline before any implementation work:

```bash
# TunerEngine tests must pass
swift test --package-path Packages/TunerEngine

# LumaDesignSystem tests must pass  
swift test --package-path Packages/LumaDesignSystem
```

If tests fail: **stop here**. Do not start implementation with a broken baseline. Report the failures and ask the user how to proceed.

If tests pass: record the baseline in a one-liner:
```
Baseline: TunerEngine ✅ N tests, LumaDesignSystem ✅ N tests
```

Optionally run benchmark for DSP-related todos:
```bash
swift run -c release --package-path Packages/TunerEngine Benchmark 2>&1 | tail -20
```

---

## Phase 2 — Triage

Read the backlog:

```bash
cat docs/ROADMAP.md
cat docs/plans/06-accuracy-engine.md  # if filter includes accuracy/plan06
```

**Triage criteria:**
- **Ready** — Has clear acceptance criteria, no blocking dependencies, tests can validate it
- **Blocked** — Depends on another item not yet done
- **Needs spec** — Unclear what "done" looks like; needs user input before starting

Apply the `[filter]` if provided. Otherwise list all backlog items.

Present the triage list to the user:
```
Ready (N):
  - [P2] <task title> — <one-line description>

Blocked (N):
  - [P3] <task title> — waiting on: <dependency>

Needs spec (N):
  - <task title> — unclear: <what's unclear>
```

Ask: "Which of these Ready items should I implement?"

---

## Phase 3 — Plan

**Domain routing — determine which specialist to dispatch per task:**

| Affected files | Specialist agent |
|----------------|-----------------|
| `TunerEngine/DSP/`, `PitchPipeline`, `AnalysisConfig`, `Bench/` | `dsp-specialist` |
| `LumaDesignSystem/Strobe/`, `*.metal` | `strobe-specialist` |
| `App/*.swift`, `App/Engine/`, `LumaDesignSystem/Components/`, `LumaDesignSystem/Tokens/` | `swiftui-specialist` |
| `*Tests/`, `Bench/`, accuracy-related | `testing-specialist` |
| Multi-domain or cross-cutting | dispatch all relevant specialists |

For each selected task, dispatch the appropriate specialist agent with this brief:

> You are planning the implementation of: **[task title]**
>
> Description: [task description from ROADMAP or plan file]
> Plan file to read: `docs/plans/[file].md §[section]` (if applicable)
> Expected affected files: [list from domain table above]
>
> Steps:
> 1. Check `docs/solutions/` for a tight-match solution first (`grep -r "applies_to" docs/solutions/`). If found, include it in your plan as a short-circuit.
> 2. Use LSP to map the blast radius: `workspaceSymbol` → `findReferences` / `outgoingCalls` on the key symbols being changed.
> 3. Return a structured implementation plan — not implementation. Discovery and planning only.
>
> Return: affected files, implementation steps, test commands, accuracy risk (yes/no), and any solutions/ short-circuit found.

Dispatch independent tasks in parallel. Collect all plans before proceeding.

Present each specialist's plan to the user. Wait for approval before Phase 4.

---

## Phase 4 — Execute

**Setup (same isolation logic as before):**

Independent tasks → create a worktree per task:
```bash
git worktree add ../luma-<slug> -b feat/<slug>
```
Sequential or shared-state tasks → single branch:
```bash
git checkout -b feat/<slug>
```

**Dispatch the specialist agent for each task:**

Brief the same specialist from Phase 3 with:

> You are implementing: **[task title]**
>
> Approved plan: [paste the plan returned in Phase 3]
> Working directory: [worktree path or current branch]
>
> Steps:
> 1. Check `docs/solutions/` one more time for the short-circuit identified in planning.
> 2. Implement the change per the approved plan.
> 3. Run the relevant test suite:
>    - DSP change: `swift test --package-path Packages/TunerEngine`
>    - Strobe/UI change: `swift test --package-path Packages/LumaDesignSystem`
>    - Accuracy-critical: also run `swift run -c release --package-path Packages/TunerEngine Benchmark`
> 4. If tests pass → commit: `feat(<domain>): <description>`
> 5. If tests fail → stop. Report the failure. Do not commit.

Dispatch independent tasks in parallel (one specialist per worktree). Wait for all to complete before the review pass.

**After all tasks complete — dispatch code-reviewer:**

Brief code-reviewer with:

> Review the changes just implemented across these commits/worktrees: [list]
>
> Focus on: package boundary violations, Swift concurrency safety, test coverage gaps, any accuracy spec risk.
> Report findings only — do not fix anything.

If code-reviewer returns **Critical or High** findings → surface them to the user and stop before merging.
If **Low/Medium only or clean** → report and proceed.

**Closing:**
```
All N todos implemented and tested.
Code-reviewer pass: [summary or "clean"].
Recommend: /codify to preserve any non-obvious patterns discovered during implementation.
```

---

## Notes

- Never skip Phase 1 (baseline). Implementing on a broken test suite hides regressions.
- Never relax an accuracy gate to make a test pass. If a DSP change causes regression, that is signal — investigate, don't suppress.
- Phase 4 worktree isolation is optional for solo work, but strongly recommended when implementing two unrelated features simultaneously.
- **Todo file convention** (`docs/todos/README.md`): one `P<n>-<slug>.md` per todo (P0 blocker … P3 low), frontmatter copied from `_TEMPLATE.md`. When triaging, **verify each open todo against current code** — these files go stale (a prior sweep found 45 of 52 already done). On completion, `git mv` the file into `docs/todos/archive/` instead of deleting it (preserves the resolution trail). Skip `README.md`, `_TEMPLATE.md`, and `archive/` when listing open todos.
