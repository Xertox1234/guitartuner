# LiveTunerModel.idle computed property is dead code after isIdle moved into StrobeInput

**Severity:** Medium
**Audit:** 2026-06-15-full (post-review)
**Domain:** swiftui

## Problem

`LiveTunerModel.idle: Bool { cents == nil }` (line 61) is now dead code. All callers — `StrobeField(idle: model.idle)`, `StageView(idle: model.idle)`, `MenuBarTuner` — were removed in audit/2026-06-15-critical-high-fixes as part of the H2 StrobeInput contract fix. Idle state is now carried inside `StrobeInput.isIdle`, set directly on `model.strobeInput` in `stop()` and the watchdog.

## Fix

- Remove `var idle: Bool { cents == nil }` from `LiveTunerModel.swift`
- Verify no remaining callers: `grep -rn "model\.idle\|\.idle" LUMA/App/`

## Files

- `App/Engine/LiveTunerModel.swift` (line 61)
