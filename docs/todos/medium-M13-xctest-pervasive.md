# Pervasive XCTest usage — 16 of 19 TunerEngine test files use legacy framework

**Severity:** Medium  
**Audit:** 2026-06-15-full  
**Domain:** testing

## Problem

Only 3 TunerEngine files and 1 LumaDesignSystem file use Swift Testing. All other test files use `XCTestCase`. New tests added to legacy files must use `@Test`/`#expect`, and files should be migrated opportunistically.

## Fix

- Audit all test files in `Packages/TunerEngine/Tests/TunerEngineTests/`
- Mark legacy test files for eventual migration
- Enforce that new tests in legacy files use Swift Testing syntax
- Migrate one or two key files per sprint if resource-constrained

## Files

- `Packages/TunerEngine/Tests/TunerEngineTests/` (bulk)
