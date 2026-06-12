---
severity: high
audit: 2026-06-12-full
finding: H4
status: partial
---

# H4 — Add LUMATests Target and Write LockGate Tests

The testability seam is in place: `LockGate.swift` is a pure struct with an injectable
`now: Date` parameter, and `handleLock` in `LiveTunerModel` is fully driven by it.

What's missing: there is no `LUMATests` Xcode target in `project.yml`, so there is
nowhere to run app-layer unit tests.

**To complete this finding:**

1. Add a `LUMATests` test target to `project.yml`:
   ```yaml
   LUMATests:
     type: bundle.unit-test
     platform: macOS
     sources: LUMA/Tests
     dependencies:
       - target: LUMA
   ```
2. Run `xcodegen generate` to regenerate the `.xcodeproj`.
3. Write tests in `LUMA/Tests/LockGateTests.swift` covering:
   - Rising edge fires haptic + ping exactly once
   - Second consecutive locked reading fires nothing
   - Ping is suppressed within cooldown, haptic still fires
   - Ping re-arms after cooldown expires
   - `reset()` clears cooldown so immediate re-lock pings again

**Files:** `project.yml`, `LUMA/Tests/LockGateTests.swift` (new)
