---
severity: low
audit: 2026-06-14-monetization-pr29
finding: L7
---

# L7 — isLoading + defer on Same Line (Non-Idiomatic Swift)

Several async methods in the monetization layer use a single-line form:

```swift
isLoading = true; defer { isLoading = false }
```

This is technically correct but non-idiomatic — SwiftLint's `statement_position` rule
will flag the semicolon, and it obscures the defer scope at a glance.

**Files:**
- `App/Account/AccountModel.swift`
- `App/Tunings/TuningCardStore.swift`

**Fix:** Split onto two lines:

```swift
isLoading = true
defer { isLoading = false }
```
