# FixturesTests temp directory path uses UUID().uuidString — non-deterministic

**Severity:** Low  
**Audit:** 2026-06-15-full  
**Domain:** testing

## Problem

A different filesystem path on every test run prevents path-based caching in CI. Does not affect test correctness but reduces reproducibility.

## Fix

- Use a fixed subdirectory name or `ProcessInfo.processInfo.processIdentifier`
- Ensure the temp directory is cleaned up between test runs (or use `XCTUnwrap` with proper cleanup)

## Files

- `Packages/TunerEngine/Tests/TunerEngineTests/FixturesTests.swift`
