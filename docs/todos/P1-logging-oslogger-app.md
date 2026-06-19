---
priority: P1
status: open
domain: security
source: docs/audits/2026-06-18-patterns-vs-best-practices.md (A-1)
---

# Migrate App/ logging from print to os.Logger, then promote the gate to HARD/CI

## Problem

`App/` logs recoverable-path failures with `print("[LUMA] …")`, including raw `\(error)` objects on network/auth paths that handle email + tokens. `print` is unredacted stderr — no `.private` redaction, no levels. `docs/rules/security.md` now requires `os.Logger`.

## Fix

- Introduce an `os.Logger` (subsystem `com.luma.app`) per area; replace `print("[LUMA] …")` call sites in `App/` with logger calls, using `\(value, privacy: .private)` on any error/PII interpolation.
- Update the `application-support-not-created` solution's print recommendation to point to `os.Logger`.
- In `scripts/lib/invariant-patterns.sh`, promote `inv_check_print_in_app` from `REVIEW:` to `HARD:` and confirm `./scripts/ci-invariants.sh` still exits 0.

## Files

- `App/**/*.swift` (all `print("[LUMA]` call sites)
- `docs/solutions/runtime-errors/application-support-not-created-ios-debug-assert-crash-2026-06-16.md`
- `scripts/lib/invariant-patterns.sh` (`inv_check_print_in_app`)

## Verification

Build the app (`xcodebuild build`), run `./scripts/ci-invariants.sh` → 0 HARD. UI-only; no DSP benchmark involved.
