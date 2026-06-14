---
severity: high
audit: 2026-06-14-monetization-pr29
finding: H5
---

# H5 — Sign In With Apple Button Invisible in Light Mode

`AccountSheet.authForm` uses `.signInWithAppleButtonStyle(.whiteOutline)` — a white button
on a `Form`'s white background. In light mode this renders as a nearly invisible rectangle.

**File:** `App/Views/Monetization/AccountSheet.swift` — `.signInWithAppleButtonStyle(.whiteOutline)` line

**Fix:** Change to `.black`, which is readable in both light and dark mode:

```swift
SignInWithAppleButton(.signIn, onRequest: ..., onCompletion: handleAppleResult)
    .signInWithAppleButtonStyle(.black)
    .frame(height: 44)
```

Apple's HIG recommends `.black` as the default style. Use `.white` only when placing the
button on a dark/colored background.

**Verify:** Open `AccountSheet` preview in both light and dark appearance — button should be
clearly visible in both.
