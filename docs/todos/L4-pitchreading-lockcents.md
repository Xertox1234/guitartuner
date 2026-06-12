---
severity: low
audit: 2026-06-12-full
finding: L4
---

# L4 — `PitchReading.isLocked` Default `lockCents` Not Linked to `LumaMusic.lockCents`

`isLocked(lockCents: Double = 3.0)` hardcodes `3.0`. `LumaMusic.lockCents` is also `3.0`
but they are unlinked across packages. `TunerEngine` must not import `LumaDesignSystem`,
so the constant can't be shared directly.

**File:** `TunerEngine/PitchReading.swift` (line 51)

**Options:**
- Move `lockCents` into `TunerEngine` (e.g., `AnalysisConfig.lockCents`) and re-export
  from `LumaDesignSystem.LumaMusic`.
- Add a test asserting `LumaMusic.lockCents == 3.0` as a compile-time coupling guard.
