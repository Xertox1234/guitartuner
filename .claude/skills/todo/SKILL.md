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

For each selected todo:

**Check docs/solutions/ for a verified short-circuit:**
```bash
grep -r "applies_to" docs/solutions/ | grep "<relevant file pattern>"
```
If a solution file's `applies_to` glob tightly matches the affected file AND the solution's `tags` overlap the domain → read that solution first. It may contain the full answer — skip the research phase.

**Otherwise, draft an implementation approach:**
1. Read the relevant plan file (e.g., `docs/plans/06-accuracy-engine.md` §P2)
2. Identify affected files using domain knowledge
3. Note which tests will validate the change
4. Estimate risk: does this touch DSP accuracy? (if yes, benchmark required after)

Present the plan for each selected item. Wait for approval before Phase 4.

---

## Phase 4 — Execute

For each approved item:

**If tasks are independent (no shared state):**
Use a git worktree for isolation:
```bash
git worktree add ../luma-<slug> -b feat/<slug>
```
Then implement in the worktree. See `superpowers:using-git-worktrees` skill for the full pattern.

**If tasks are sequential or share state:**
Implement one at a time on the current branch or a new branch:
```bash
git checkout -b feat/<slug>
```

**For each task:**
1. Check `docs/solutions/` one more time for a tight-match solution (the short-circuit from Phase 3)
2. Implement the change
3. Run the relevant test suite:
   - DSP change: `swift test --package-path Packages/TunerEngine`
   - Strobe/UI change: `swift test --package-path Packages/LumaDesignSystem`
   - Accuracy-critical: also run `swift run -c release --package-path Packages/TunerEngine Benchmark`
4. If tests pass → commit with conventional message: `feat(<domain>): <description>`
5. If tests fail → stop, surface failure, do not commit

**After all tasks complete:**
```
All N todos implemented and tested.
Recommend: /codify to preserve any non-obvious patterns discovered during implementation.
```

---

## Notes

- Never skip Phase 1 (baseline). Implementing on a broken test suite hides regressions.
- Never relax an accuracy gate to make a test pass. If a DSP change causes regression, that is signal — investigate, don't suppress.
- Phase 4 worktree isolation is optional for solo work, but strongly recommended when implementing two unrelated features simultaneously.
