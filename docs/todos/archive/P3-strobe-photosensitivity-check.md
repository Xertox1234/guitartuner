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

## Resolution (2026-06-19/20, sub-project 3 / C-4)

Analyzed (C-4a, commits `492919e` + `b742fb6`) and **mitigated** (C-4b, commit
`c8841c1`). Analysis doc:
`docs/solutions/accessibility/strobe-photosensitivity-2026-06-19.md`; one-line
record added to `docs/rules/strobe.md`.

**Verdict: HAZARD (not "likely safe").** The off-pitch strobe is a full-screen,
high-contrast, rigidly-translating N-band pattern; a fixed point flickers at
`N × beat-rate` (N=13 Aurora / 36 Radial), exceeding WCAG 2.3.1's 3/sec across the
normal tuning range, with a ≈0.40 luminance swing — no escape hatch holds. A
strobe-specialist independently confirmed (AGREE-HAZARD).

**Mitigation (Lever C, product-owner choice): aesthetic rate ceiling + danger-band
brightness dim**, applied CPU-side in all four full-screen renderers (no MSL edits —
folded into the existing `dim` uniform). Pure `StrobeMath` helpers, verified by a
**compliance-invariant** test (∀ rate: region flicker ≤ 3/sec OR swing ≤ 10% of
max), not clamp mechanics. Lock-eased → the in-tune bloom is byte-identical.
Strobe-specialist review: APPROVED. The verification is of the safety *logic* given
the C-4a luminance model, not an on-device flash measurement (a documented
follow-up: revisit `shimmerFloor` margin on first on-device measurement).
