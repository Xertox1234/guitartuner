---
severity: medium
audit: 2026-06-12-full
finding: M6
---

# M6 — `hapticsEnabled` and `a4` Don't Persist Across Launches

Both are declared as plain `var`s on `LiveTunerModel` and reset to defaults (`true`, `440`)
on every launch. `hapticsEnabled` is bound via `@Bindable` in `SettingsView`, so users
who turn off haptics will find them re-enabled next launch.

**File:** `App/Engine/LiveTunerModel.swift` (lines 43, 47)

**Fix:** Back both with `@AppStorage`:
- `@ObservationIgnored @AppStorage("hapticsEnabled") var hapticsEnabled = true`
- `@ObservationIgnored @AppStorage("a4Calibration") private var storedA4: Double = 440`
  with the clamping/`applyA4()` logic unchanged, reading from `storedA4` on init.
