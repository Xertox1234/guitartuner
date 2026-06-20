---
priority: P2
status: needs-spec
domain: testing
source: 2026-06-15-full audit (M13)
---

# Pervasive XCTest usage — legacy XCTest files in TunerEngine should migrate to Swift Testing

**Severity:** Medium  
**Audit:** 2026-06-15-full  
**Domain:** testing

## Problem

New tests should use Swift Testing (`@Test`/`#expect`); remaining `XCTestCase` files should be
migrated opportunistically.

**Count refreshed 2026-06-20 (verification):** the original "16 of 19 use XCTest" is stale —
migration has progressed substantially. Of **20** files in
`Packages/TunerEngine/Tests/TunerEngineTests/`, **5** still `import XCTest` and **14**
`import Testing` (one file may use neither/both). So ~5 legacy files remain, down from 16. The
headline number undersold the progress; the work is still open but nearly done.

## Fix

- Audit all test files in `Packages/TunerEngine/Tests/TunerEngineTests/`
- Mark legacy test files for eventual migration
- Enforce that new tests in legacy files use Swift Testing syntax
- Migrate one or two key files per sprint if resource-constrained

## Files

Remaining legacy `XCTest` files (5, as of 2026-06-20):

- `Packages/TunerEngine/Tests/TunerEngineTests/BenchmarkTests.swift`
- `Packages/TunerEngine/Tests/TunerEngineTests/DiagnosisProbeTests.swift`
- `Packages/TunerEngine/Tests/TunerEngineTests/FileInputTests.swift`
- `Packages/TunerEngine/Tests/TunerEngineTests/FixturesTests.swift`
- `Packages/TunerEngine/Tests/TunerEngineTests/ToneSynthTests.swift`
