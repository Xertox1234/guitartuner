# PipelineTests accuracy tolerances 12–40× looser than CI gate

**Severity:** Medium  
**Audit:** 2026-06-15-full  
**Domain:** testing

## Problem

`abs(last.cents) < 3.0` and `sigma < 3.0` in clean-tone cases, `< 12` in another variant. CI gate enforces `cleanAbsCents ≤ 0.25¢`. A regression blowing mean error from 0.10¢ to 2.9¢ would pass unit tests but fail the benchmark gate.

## Fix

- Tighten all tolerances to `< 1.0¢` for clean-tone cases
- Document the relationship between unit test thresholds and CI benchmark gates
- Verify no valid readings are rejected by the new thresholds via regression test

## Files

- `Packages/TunerEngine/Tests/TunerEngineTests/PipelineTests.swift`
