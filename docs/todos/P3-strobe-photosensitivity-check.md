---
priority: P3
status: open
domain: accessibility
source: docs/audits/2026-06-18-patterns-vs-best-practices.md (C-4)
---

# Verify and record the strobe against WCAG 2.3.1 flash threshold

## Problem

The core feature is a strobe; `strobe.md` covers motion sensitivity but never the photosensitivity (flash) threshold. On-pitch it stands still; off-pitch it scrolls — likely safe, but unverified and unrecorded.

## Fix

- Analyze the off-pitch animation's flash rate × luminance-delta × screen-area against WCAG 2.3.1 ("three flashes or below threshold").
- Record the result (and any mitigation) as a one-line note in `docs/rules/strobe.md`.

## Files

- `Packages/LumaDesignSystem/Sources/LumaDesignSystem/Strobe/*` (animation params)
- `docs/rules/strobe.md` (record the check)

## Verification

Documented determination that the off-pitch animation is within the WCAG 2.3.1 threshold (or a mitigation if not).
