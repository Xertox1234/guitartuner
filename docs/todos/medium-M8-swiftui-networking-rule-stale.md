# swiftui.md "No networking in v1" rule is stale — generates false audit signals

**Severity:** Medium  
**Audit:** 2026-06-15-full  
**Domain:** swiftui

## Problem

The rule in `docs/rules/swiftui.md` reads "No networking in v1. Do not add URLSession...". The committed monetization stack (`LumaAPI`, `AccountModel`, `TuningCardStore`, `GearStoreModel`) uses URLSession with explicit user consent. Audio stays on-device; the privacy invariant is intact. The rule must be updated to clarify this distinction.

## Fix

- Update `docs/rules/swiftui.md` to clarify that audio is on-device by architecture, but opt-in account networking is permitted
- Document the monetization backend (`LumaAPI`) as the intentional networking exception
- Add a note to prevent future false-positive audit signals

## Files

- `docs/rules/swiftui.md`
