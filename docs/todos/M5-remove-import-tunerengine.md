---
severity: medium
audit: 2026-06-12-full
finding: M5
---

# M5 — Unused `import TunerEngine` in App Views

`LiveTunerScreen.swift` and `SettingsView.swift` both have `import TunerEngine` on line 3,
but neither file uses any `TunerEngine` symbol — all types resolve to `LumaDesignSystem`.
A dead import today is an invitation to reach through the package boundary tomorrow.

**Fix:** Remove `import TunerEngine` from:
- `LUMA/App/LiveTunerScreen.swift` (line 3)
- `LUMA/App/SettingsView.swift` (line 3)

Build will fail if the import was actually needed — that failure is the signal.
