---
severity: low
audit: 2026-06-14-monetization-pr29
finding: L5
---

# L5 — Dead marketingEmail State Variable in AccountSheet

`AccountSheet` declares `@State private var marketingEmail: String = ""` but never
writes to it. The subscribe flow correctly uses `email` (the registration/login field).
`marketingEmail` is a leftover from an earlier design iteration.

**File:** `App/Views/Monetization/AccountSheet.swift`

**Fix:** Remove the `marketingEmail` declaration entirely.
