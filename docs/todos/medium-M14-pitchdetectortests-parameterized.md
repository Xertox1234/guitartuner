# PitchDetectorTests has copy-paste per-note test functions — needs parameterization

**Severity:** Medium  
**Audit:** 2026-06-15-full  
**Domain:** testing

## Problem

Structurally identical functions for E2, A2, D3, G3, B3, E4 etc. repeat the same test logic. This violates the DRY principle and makes maintenance fragile.

## Fix

- Collapse into a single `@Test(arguments: [82.41, 110.0, 146.83, ...])` parameterized test per Swift Testing idiom
- Define the note frequencies as a constant array in the test
- Verify that all per-note assertions pass identically

## Files

- `Packages/TunerEngine/Tests/TunerEngineTests/PitchDetectorTests.swift`
