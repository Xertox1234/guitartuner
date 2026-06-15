# StimulusTests calls PitchDetector directly — bypasses full pipeline path

**Severity:** Medium  
**Audit:** 2026-06-15-full  
**Domain:** testing

## Problem

Stimulus stress-family tests (weak-fundamental, missing-fundamental, vibrato) feed `PitchDetector` directly, bypassing the preprocessor, adaptive windowing, and smoothing layers in `PitchPipeline`. Regressions in the integration between stress stimuli and the full pipeline would be missed.

## Fix

- Refactor tests to drive `PitchPipeline` or `CaseRunner.run(...)` instead of `PitchDetector` directly
- Verify that test results remain consistent (or update baselines if the integration changes accuracy)
- Document why the full pipeline path is necessary for stress testing

## Files

- `Packages/TunerEngine/Tests/TunerEngineTests/StimulusTests.swift`
