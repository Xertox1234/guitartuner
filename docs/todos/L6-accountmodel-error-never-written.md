---
severity: low
audit: 2026-06-14-monetization-pr29
finding: L6
---

# L6 — AccountModel.error Never Written; Fallback in AccountSheet Is Dead Code

`AccountModel` declares `var error: String?` with a comment noting it is "reserved for
background error surfacing." No code path in the model ever sets it. `AccountSheet`
reads it as a nil-coalescing fallback:

```swift
errorMessage ?? accountModel.error
```

The right-hand side is always `nil`, making the fallback dead code.

**Files:**
- `App/Account/AccountModel.swift` — `var error: String?`
- `App/Views/Monetization/AccountSheet.swift` — `errorMessage ?? accountModel.error`

**Options:**
1. Remove `AccountModel.error` entirely (cleanest if background error surfacing isn't
   planned for v1), and simplify AccountSheet to just `errorMessage`.
2. Keep it as a documented extension point but remove the nil-coalescing read in
   AccountSheet until it's actually populated.

Prefer option 1 for v1 — YAGNI.
