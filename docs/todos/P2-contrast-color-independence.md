---
priority: P2
status: open
domain: accessibility
source: docs/audits/2026-06-18-patterns-vs-best-practices.md (C-3)
---

# WCAG AA contrast audit (both appearances) + honor differentiateWithoutColor

## Problem

No codified contrast budget exists, and `accessibilityDifferentiateWithoutColor` is unhandled. State is color-coded (mint/amber/blue); dark-first risks light-mode contrast being under-validated.

## Fix

- Measure state colors + text against WCAG AA (4.5:1 text / 3:1 graphics) in light AND dark; adjust tokens that fail.
- Read `@Environment(\.accessibilityDifferentiateWithoutColor)`; ensure any color-only affordance (e.g. compact/menu-bar state dot) gains a non-color cue when enabled.

## Files

- `Packages/LumaDesignSystem/Sources/LumaDesignSystem/Tokens/LumaColor*`
- `Packages/LumaDesignSystem/Sources/LumaDesignSystem/Components/StateLine.swift`, menu-bar/compact state views

## Verification

Contrast ratios documented for both appearances; a `differentiateWithoutColor` preview shows the non-color cue.
