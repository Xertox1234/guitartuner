# Follow-ups: hardening the edit-time code-quality hooks

Date: 2026-06-16
Context: assessment of `.claude/hooks/inject-patterns.sh` (PreToolUse, advisory rule
injection). The injection hook *informs* but does not *enforce*. This plan tracks the
move toward defense-in-depth: keep injection for judgment rules, add deterministic
checks for mechanizable invariants.

## Done in this session

- [x] **Drafted PostToolUse validator** — `.claude/hooks/validate-invariants.sh`
  (executable). Verifies grep-able invariants after each Edit/Write/MultiEdit on a
  `.swift` file: forbidden imports per package (no SwiftUI/Combine/LumaDesignSystem/
  Network in TunerEngine; no TunerEngine/AVFoundation/networking in LumaDesignSystem),
  project-wide Combine ban, networking-outside-LumaAPI (soft), and `try!`/`as!` in
  production paths (soft). HARD violations + REVIEW items print to stderr and `exit 2`
  (feeds back to the model). Clean files exit 0 silently.

- [x] **Wire it in** (done 2026-06-16) — registered in the `PostToolUse` array of
  `.claude/settings.json` alongside the existing Bash entry, matcher
  `Edit|Write|MultiEdit`. Takes effect on a fresh session. For reference, the entry:

  ```json
  {
    "matcher": "Edit|Write|MultiEdit",
    "hooks": [
      {
        "type": "command",
        "command": "bash $CLAUDE_PROJECT_DIR/.claude/hooks/validate-invariants.sh",
        "timeout": 10
      }
    ]
  }
  ```

  Note: hook-config changes are picked up on a fresh session / after reviewing in
  `/hooks` — they do not take effect mid-session. Smoke-test first by piping a sample
  PostToolUse JSON payload into the script (see "Smoke-test the hook" below).

## Remaining suggestions (this is the next-session work list)

1. **Close the cheap-worker delegation hole.** `kimi-write` runs via **Bash**, so
   neither `inject-patterns.sh` (PreToolUse Edit|Write) nor the new validator
   (PostToolUse Edit|Write) fires on delegated code generation — the most error-prone
   path (cheaper model) gets zero rule coverage. Options:
   - (a) Route kimi output through Edit/Write so both hooks fire (preferred), or
   - (b) call `validate-invariants.sh` inside the delegation wrapper before accepting
     output, or
   - (c) always run the validator over any file touched by a delegated worker.

2. **Rebalance dedup salience in `inject-patterns.sh`.** After the first edit in a
   domain this session, repeats get only `[<domain> rules already injected]`. In long
   sessions the full rules scroll out of recent context. Keep deduping the verbose
   *rationale*, but re-inject a compact always-on checklist of the ~5 hard "don'ts"
   every time (cheap tokens, high salience).

3. **Add measurement.** Have `validate-invariants.sh` append a one-line log
   (domain + rule fired) to e.g. `/tmp/luma-invariant-hits` or a repo-ignored file.
   Tells you which rules are actually at risk → which injected rules are/aren't
   landing. Cheap feedback loop on whether the hooks work.

4. **Replace the heuristic force-unwrap check with SwiftLint.** The validator only
   catches `try!`/`as!` reliably; generic optional force-unwrap (`foo!`) is too noisy
   to grep (false positives in strings/comments). SwiftLint's `force_unwrapping`,
   `force_try`, `force_cast` rules do this properly via AST. Consider a SwiftLint
   config gated in CI and/or invoked from the PostToolUse hook for changed files.
   This also subsumes part of the validator.

## Already-strong layers (don't rebuild)

- **Compiler-enforced package boundary:** neither `Packages/*/Package.swift` lists the
  other as a dependency, so cross-package imports (TunerEngine ↔ LumaDesignSystem)
  *fail to compile*. The validator's cross-package import checks are belt-and-suspenders
  on top of this; the real guard is the dependency graph. (Note: system frameworks like
  SwiftUI/Combine/AVFoundation/Network still compile inside the pure packages — those
  are the ones the validator genuinely adds protection for.)
- **Commit gate:** `commit-verify.sh` (PostToolUse on Bash).
- **CI gate:** accuracy benchmark + `swift test`.

## Smoke-test the hook

Quick manual check (point `file_path` at a real `.swift` file containing `import
SwiftUI` to see the violation fire):

```bash
# Should report a VIOLATION (SwiftUI import in TunerEngine), exit 2:
printf '{"tool_name":"Write","tool_input":{"file_path":"%s/Packages/TunerEngine/Sources/TunerEngine/Foo.swift"}}' \
  "$PWD" | bash .claude/hooks/validate-invariants.sh; echo "exit=$?"
```

The full, repeatable suite lives at `.claude/hooks/tests/validate-invariants.test.sh`
(HARD vs REVIEW channels, submodule imports, comment false-positives, GearStore
scoping, tool/extension skips):

```bash
bash .claude/hooks/tests/validate-invariants.test.sh
```

The suite is currently run manually and is **not yet CI-wired**, so it can rot. A
small follow-up is to invoke it from the CI workflow (cheap; no Xcode/Swift needed —
just `bash` + `jq`) so the hook's contract is regression-guarded alongside the
accuracy benchmark.
