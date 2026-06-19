# LUMA — Security & Accessibility Governance Design Spec

**Date:** 2026-06-19
**Status:** Approved
**Scope:** Sub-project #1 of 3 — give the cross-cutting *security* and *accessibility* concerns a home in the rule system, wire them into auto-injection, and enforce the grep-able subset (local hook + CI). Captures the deferred code work as tracked todos for sub-projects #2 and #3.
**Source:** `docs/audits/2026-06-18-patterns-vs-best-practices.md` (10 findings: A:1, B:5, C:4)

---

## 1. Overview

The patterns audit (`docs/audits/2026-06-18-…`) found that LUMA's codified rules are organized **by architectural domain** (`dsp`, `capture`, `pipeline`, `strobe`, `swiftui`, `design-system`, `testing`). Security and accessibility are **cross-cutting** — they belong to no single domain, so they have no home file and surface only incidentally (Reduce Motion happens to live in `strobe.md`; URL-auth safety in `swiftui.md`). That structural blind spot is the root cause of most of the audit's Tier-B/C findings.

This sub-project fixes the **root cause**, not the symptoms: it creates the two missing home rule files, wires them into the existing inform-then-enforce hook machinery as cross-cutting domains, and adds enforcement (local + CI) for the deterministic subset. The actual code changes (logging, Keychain class, Reduce Transparency, Dynamic Type, contrast, photosensitivity) are **out of scope here** and become tracked todos feeding sub-projects #2 (security code) and #3 (accessibility code).

### 1.1 Decisions taken during brainstorming

| Decision | Choice |
|----------|--------|
| Ambition | Both governance + code, **root-cause (governance) first** |
| Slicing | **Decompose** into 3 sub-projects; fully design #1 (this spec) now |
| Teeth | **Full program + CI** — advisory homes + enforced guardrails + CI gate + PR checklist |

### 1.2 Guiding principle — single source of truth

Each cross-cutting rule is owned **canonically by its home file** (`security.md` / `accessibility.md`). Domain files (`strobe.md`, `swiftui.md`, `capture.md`) keep only operational specifics and **link up** to the home — no duplication. (Scattering the same rule across files is the exact mess the audit flagged.)

---

## 2. Deliverables

1. `docs/rules/security.md` + `docs/rules/accessibility.md` — canonical homes (§3)
2. Cross-cutting injection wiring: `domain-map.sh`, `domain_rank`, solution `tags:`, CLAUDE.md `## Domains` table (§4)
3. Enforcement: `scripts/lib/invariant-patterns.sh` (SSOT) consumed by `validate-invariants.sh` (local) + `scripts/ci-invariants.sh` (CI), with a new CI `invariants` job (§5)
4. `.github/PULL_REQUEST_TEMPLATE.md` — accessibility + security checklist (§6)
5. `docs/todos/` entries for the deferred code (§7) + `security`/`accessibility` added to the todo template `domain:` enum
6. Hook/CI tests (§8)

No application (`App/`, `Packages/`) Swift code is modified in this sub-project.

---

## 3. The two rule files

### 3.1 `docs/rules/security.md`

Consolidates today's scattered security rules and codifies the audit's Tier-B "code already does it right, write it down" items:

- **Audio privacy is architectural** — `TunerEngine` has no networking; audio is never recorded, stored, or transmitted. Canonical home; `capture.md` / `swiftui.md` link here.
- **All backend networking lives in `LumaAPI` only.** HTTPS-only; **no ATS exceptions** (`NSAllowsArbitraryLoads`).
- **API route construction** via `LumaAPI.buildURL` / `appending(path:)`, never `appending(component:)` — it percent-encodes slashes, breaking multi-segment routes. Scope: **route strings only**. `appending(component:)` is *correct* for a single-segment **filesystem** name (e.g. `TuningCardStore` / `GearStoreModel` building their `…json` cache filenames) — do not ban it there. → links `url-appending-component-encodes-slashes`.
- **Tokens/secrets in Keychain**, never `UserDefaults` / JSON cache; `kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly` (preserves background refresh, blocks backup-restore migration).
- **Account data** — only email, opt-in, declared in `PrivacyInfo.xcprivacy`. **Account deletion must purge Keychain tokens + cached account JSON.** Scope privacy claims to "audio never leaves the device / no account required to tune."
- **Logging** — `os.Logger` with `.private` qualifiers in `App/`; never `print` PII / secrets / raw error objects on network or auth paths.
- **Never `assertionFailure` / `fatalError` / `precondition` on a recoverable path** (cache / network / decode) — log and degrade. → links `application-support-not-created…`.
- **Keep `PrivacyInfo.xcprivacy` accurate** when adding any collected data type or required-reason API.

### 3.2 `docs/rules/accessibility.md`

Promotes Reduce Motion to canonical and codifies the rest of the audit's accessibility findings:

- **Reduce Motion** → substitute `ReducedGauge`; do not merely slow the animation. Canonical home; `strobe.md` keeps the operational line + links here.
- **Reduce Transparency** → attenuate additive bloom / `FieldWash` translucency. *(new — audit C-1)*
- **Dynamic Type** → chrome / settings / informational text scales (`.custom(_:size:relativeTo:)` / `@ScaledMetric`); the primary instrument readout (note / strobe) may opt out, but **deliberately and documented**. *(audit C-2)*
- **VoiceOver** → interactive / stateful components require an `accessibilityLabel`; pitch-bearing views expose a live `accessibilityValue` ("in tune", signed cents). Required for new components, parallel to the `#Preview` rule. *(audit B-5)*
- **Color independence** → never signal state by color alone; honor `accessibilityDifferentiateWithoutColor`. Preserve the existing redundancy (textual state + strobe scroll direction + signed cents). *(audit C-3)*
- **Contrast** → WCAG AA (4.5:1 text / 3:1 graphics) in **both** appearances; validate light mode (dark-first must not leave light under-checked). *(audit C-3)*
- **Photosensitivity** → the off-pitch strobe animation is verified against the WCAG 2.3.1 flash threshold (rate × luminance-delta × area); record the check. *(audit C-4)*
- **Haptics** → the in-tune lock haptic is a non-visual confirmation channel; preserve it.

---

## 4. Cross-cutting injection wiring

### 4.1 `domain-map.sh` — two additive blocks

`get_domains()` is a sequence of independent `if … echo` blocks; a file already matches multiple domains. Add:

```bash
# security — networking, auth/token storage, persistence, privacy surface
if [[ "$path" == */App/Networking/* ]] || [[ "$path" == */App/Account/* ]] || \
   [[ "$path" == */App/Persistence/* ]] || [[ "$path" == */App/Store/* ]] || \
   [[ "$path" == *LumaAPI* ]] || [[ "$path" == *LumaConfig* ]] || \
   [[ "$path" == *Keychain* ]] || [[ "$path" == *CacheFile* ]] || \
   [[ "$path" == *MicrophonePermission* ]] || \
   [[ "$path" == *.entitlements ]] || [[ "$path" == *Info.plist ]] || \
   [[ "$path" == *PrivacyInfo.xcprivacy ]]; then
  echo "security"
fi

# accessibility — anything user-facing
if [[ "$path" == */App/*.swift ]] || [[ "$path" == */Components/* ]] || \
   [[ "$path" == */Strobe/* ]] || [[ "$path" == */Gallery/* ]]; then
  echo "accessibility"
fi
```

### 4.2 `domain_rank`

```bash
security)      echo 5  ;;   # cross-cutting, surface first / never spilled
accessibility) echo 15 ;;   # cross-cutting, high priority
```

### 4.3 Notes

- `inject-patterns.sh` fires on Edit/Write of **any** file path (it does not restrict to `.swift`), so `security.md` correctly surfaces when editing `Info.plist`, `*.entitlements`, or `PrivacyInfo.xcprivacy`.
- Add `security` to the `tags:` frontmatter of: `macos-audio-input-entitlement…`, `mic-permission-denied…`, `logic-errors/url-appending-component-encodes-slashes…`, `runtime-errors/application-support-not-created…`. No accessibility *solution* exists yet — the rule file carries it until one is codified.
- CLAUDE.md `## Domains`: add two rows, marked **cross-cutting (co-injected alongside the architectural domain)**:

  | Domain | Files | Rules |
  |--------|-------|-------|
  | `security` | `App/Networking/*`, `App/Account/*`, `App/Persistence/*`, `*.entitlements`, `Info.plist`, `PrivacyInfo.xcprivacy` | `docs/rules/security.md` |
  | `accessibility` | `App/*.swift`, `Components/*`, `Strobe/*`, `Gallery/*` | `docs/rules/accessibility.md` |

---

## 5. Enforcement + staged gating

### 5.1 Single source of truth

Extract the deterministic checks (pattern + message + severity) into `scripts/lib/invariant-patterns.sh`. Two consumers source it — no drift:

- `validate-invariants.sh` — per-file, local PostToolUse hook (existing).
- `scripts/ci-invariants.sh` — repo-wide scan, run in CI (new).

### 5.2 The staged-gate constraint

**You can only hard-gate an invariant the codebase already satisfies.** Enforcement is therefore staged; the "promote" step for the two currently-violated rules lives *inside* the sub-project #2 todos, so fixing the code and flipping the gate are one unit of work.

| Rule | Code today | Now | After #2 |
|------|-----------|-----|----------|
| `NSAllowsArbitraryLoads` / ATS exception (any plist) | clean ✓ (verified) | **HARD + CI** | — |
| `appending(component:` **scoped to `App/Networking/` + `*LumaAPI*`** (route strings) | clean ✓ (verified — the two cache stores use it legitimately for filenames and are *out of scope*) | **HARD + CI** | — |
| networking (`URLSession`/`URLRequest`/`import Network`) outside the `networking_allowed()` allow-list | clean ✓ (verified — only `LumaAPI` + allow-listed sites) | **HARD + CI** | — |
| `print(` in `App/` production | **violates** (current convention) | REVIEW (local only) | **promote → HARD + CI** |
| Keychain without `…ThisDeviceOnly` | **violates** | REVIEW (local only) | **promote → HARD + CI** |
| `assertionFailure`/`fatalError` on recoverable path | mostly clean | REVIEW only (heuristic) | stays REVIEW |
| `.custom(…size:)` without `relativeTo:` (a11y) | violates | REVIEW only (heuristic) | stays REVIEW |

The networking-outside-`LumaAPI` check already exists in `validate-invariants.sh` as a soft REVIEW; this promotes its deterministic part to HARD/CI (the allow-list in `networking_allowed()` is reused).

### 5.3 CI job

Add to `.github/workflows/ci.yml` (fast, no Xcode, runs in parallel with `engine` / `app`):

```yaml
  invariants:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - name: Security invariants
        run: ./scripts/ci-invariants.sh   # exit non-zero on any HARD violation
```

### 5.4 Grep-pattern cautions (avoid self-inflicted false positives)

The patterns in `invariant-patterns.sh` must be written carefully — a naive grep breaks the rule it's meant to enforce:

- **Keychain — substring trap.** `kSecAttrAccessibleAfterFirstUnlock` is a **prefix** of the *correct* `…AfterFirstUnlockThisDeviceOnly`, so a bare match for the bad form also matches the good form. After sub-project #2 switches to `…ThisDeviceOnly`, a naive check would keep firing on now-correct code — and the "promote → HARD+CI" step would then **block the build on correct code**. Match "`AfterFirstUnlock` **not** followed by `ThisDeviceOnly`" (e.g. `AfterFirstUnlock([^T]|$)`, or a two-step grep: line contains `AfterFirstUnlock` AND not `ThisDeviceOnly`). Also intentionally allow `…WhenUnlockedThisDeviceOnly` and other `…ThisDeviceOnly` classes.
- **`print(` — anchor it.** `grep 'print('` also hits `debugPrint(`, `sprint(`, `fingerprint(`. Anchor with `\bprint(`. Decision: **also flag `\bdebugPrint(`** (it emits the same uncontrolled output) — so the pattern is `\b(print|debugPrint)\(`. REVIEW-only, so residual noise is tolerable, but anchoring keeps it honest.
- **`appending(component:` — scope, don't broaden.** Enforce only within `App/Networking/` + `*LumaAPI*` (§5.2). The repo grep in `ci-invariants.sh` must restrict its path glob accordingly so the two cache stores never trip it.

---

## 6. Accessibility + security PR checklist

New `.github/PULL_REQUEST_TEMPLATE.md` — the human gate for the non-grep-able items (especially accessibility):

```markdown
## Summary

## Accessibility (delete rows that don't apply)
- [ ] Reduce Motion honored (ReducedGauge fallback where animated)
- [ ] Reduce Transparency honored (bloom / wash attenuated)
- [ ] Dynamic Type scales chrome/settings text (or opt-out documented)
- [ ] accessibilityLabel on interactive elements; live accessibilityValue on pitch views
- [ ] No color-only state; differentiateWithoutColor honored
- [ ] WCAG AA contrast in both light and dark
- [ ] (Strobe/animation) checked vs WCAG 2.3.1 flash threshold

## Security
- [ ] No networking outside LumaAPI; HTTPS only (no ATS exception)
- [ ] Secrets in Keychain (…ThisDeviceOnly), not UserDefaults/cache
- [ ] No PII/secrets in print/logs (os.Logger + .private)
```

---

## 7. Backlog — todos feeding sub-projects #2 and #3

Extend `docs/todos/_TEMPLATE.md` `domain:` enum to include `security · accessibility`. Create:

| File | Finding | Priority | Domain |
|------|---------|----------|--------|
| `P1-logging-oslogger-app.md` | A-1: migrate `App/` `print` → `os.Logger` (+ `.private`); **then promote the print-in-App gate to HARD/CI** | P1 | security |
| `P1-keychain-thisdeviceonly.md` | B-1: switch token entries to `…ThisDeviceOnly`; **then promote the Keychain gate to HARD/CI** | P1 | security |
| `P2-account-delete-purge-verify.md` | B-4: verify account deletion purges Keychain tokens + cached account JSON | P2 | security |
| `P2-reduce-transparency.md` | C-1: honor Reduce Transparency in bloom / `FieldWash` | P2 | accessibility |
| `P2-dynamic-type-chrome.md` | C-2: scale chrome/settings text via `relativeTo:`/`@ScaledMetric` | P2 | accessibility |
| `P2-contrast-color-independence.md` | C-3: WCAG AA audit (both modes) + honor `differentiateWithoutColor` | P2 | accessibility |
| `P3-strobe-photosensitivity-check.md` | C-4: verify + record WCAG 2.3.1 flash-threshold check | P3 | accessibility |

Audit items **B-2** (ATS), **B-3** (privacy-claim scoping), **B-5** (VoiceOver requirement) are codified directly into the rule files in this sub-project — no todo needed. **A-1** and **B-1** are *also* partially addressed here (the REVIEW gate ships now); their todos cover the code fix + gate promotion.

---

## 8. Verification

This sub-project touches no app Swift, but the hooks and CI are testable:

- Extend `.claude/hooks/tests/validate-invariants.test.sh`: ATS-exception fixture → HARD (exit 2); clean file → silent; `print` in an `App/` file → REVIEW; Keychain without `…ThisDeviceOnly` → REVIEW.
- Assert `get_domains` returns `swiftui`+`security` for `KeychainStore.swift`, and `design-system`+`accessibility` for a component under `Components/`.
- Run `./scripts/ci-invariants.sh` against the current repo → **must pass**. A failure means a "now-gated" rule is not actually satisfied today (mis-scoped) — re-stage it to REVIEW.
- Smoke-test `inject-patterns.sh` with a UI-file stdin → confirm `accessibility` rules appear and output is valid JSON.
- Existing hook test suite stays green.

---

## 9. Out of scope (later sub-projects)

- **Sub-project #2 — security code:** A-1 (`os.Logger` migration), B-1 (Keychain class), B-4 purge verification, and promotion of their gates to HARD/CI. Own spec → plan → implementation.
- **Sub-project #3 — accessibility code:** C-1…C-4. Own spec → plan → implementation. These touch the visual identity (bloom attenuation, text scaling, contrast, color independence) and warrant their own brainstorming on the accessibility-vs-aesthetic trade-offs.

---

## 10. Risks & mitigations

- **Injection noise:** `accessibility` matches most UI files, so it co-injects on nearly every UI edit. Mitigated by the hook's per-session dedup (full rules once, one-line pointer after) and the 9 KB byte cap with spill-to-temp.
- **CI false positives:** only deterministic, already-satisfied rules are CI-blocking; everything heuristic stays local REVIEW. The §8 "must pass against current repo" check guarantees the gate is green at landing.
- **Drift between local hook and CI:** prevented by the single `scripts/lib/invariant-patterns.sh` source of truth (§5.1).
- **Plist scanning:** `validate-invariants.sh` currently early-exits on non-`.swift`; the ATS check operates on `Info.plist`/entitlements, so the plist patterns live in the shared lib and run via `ci-invariants.sh` (repo scan) and a narrowly-scoped path branch in the local hook.
