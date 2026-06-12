---
severity: medium
audit: 2026-06-12-full
finding: M3
---

# M3 — `minLockConfidence` Still Hardcoded in `PitchReading.isLocked`

`PitchReading.isLocked(minConfidence: Double = 0.9)` hardcodes 0.9 as a default.
`LiveTunerModel` uses a per-band threshold (0.75 bass / 0.9 mid+high) in `.lock` mode
(fixed by H1), but the `.auto` mode path still calls `r.isLocked()` which uses the
hardcoded default.

These two thresholds are unlinked — a future product change to one won't update the other.

**File:** `TunerEngine/PitchReading.swift` (line 51); `App/Engine/LiveTunerModel.swift`

**Fix:** Define a `lockConfidence` constant in `LumaMusic` (alongside `lockCents`) and pass
it explicitly at all call sites, or add a test asserting both sides agree.
