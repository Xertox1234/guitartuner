---
priority: P3
status: open
domain: design-system
source: 2026-06-21 P3-lightmode-palette-aa fix (aurora done; siblings deferred)
depends_on: docs/todos/archive/P3-lightmode-palette-aa.md
---

# Light-mode AA for the four non-aurora palettes (amber/neon/forest/crimson)

## Problem

The 2026-06-21 two-tier fix made **aurora** light-mode state colors meet WCAG AA
(tag text 4.5:1 via the colorset tokens; strobe ribbons 3:1 via
`StrobePalette.chroma(.aurora, .light)`). The other four palettes were **not** audited
or fixed and almost certainly fail light AA too: e.g. `amber` light `tune #C9A227`,
`neon` light `sharp #E6007E`, `forest`/`crimson` light slots are similarly mid-tone on
the `#E7EAF1` background.

This is latent because `ContrastAuditTests` only gates aurora (the default/signature
palette), and dark mode — the strobe tuner's primary appearance — passes AA for every
palette. So a user on a non-aurora palette in light mode may see sub-AA ribbons today.

Note: the **tag text** is already safe for every palette — after the aurora fix,
`StateLine` colours the tag from the `flat`/`sharp`/`inTune` *colorset* tokens (4.5:1)
for all states and is palette-agnostic. So this todo is specifically about the **strobe
ribbon graphics** (3:1) for the non-aurora palettes.

## Fix

For each of `amber`/`neon`/`forest`/`crimson`, nudge the `chroma(_, .light)` primary
slots (`flat`/`sharp`/`tune`, and `*2` if they fall below 3:1) darker to clear the 3:1
graphic threshold, preserving hue (scale in linear-RGB — same method as the aurora fix,
see `docs/solutions/accessibility/state-color-contrast-audit-2026-06-19.md`). Keep the
darkening minimal so the alternate palettes stay vivid.

Then extend `strobeGraphicContrast_light` to assert all five palettes (loop over
`LumaPalette.allCases`), not just aurora.

## Files

- `Packages/LumaDesignSystem/Sources/LumaDesignSystem/Strobe/StrobePalette.swift`
  (`chroma(_:_:)` — `.amber`/`.neon`/`.forest`/`.crimson` light branches)
- `Packages/LumaDesignSystem/Tests/LumaDesignSystemTests/ContrastAuditTests.swift`
  (`strobeGraphicContrast_light` — loop over all palettes)

## Verification

`swift test --package-path Packages/LumaDesignSystem` — `strobeGraphicContrast_light`
asserts ≥ 3:1 for every `LumaPalette` in light mode. Design-system only; no DSP/accuracy
path, no benchmark gate. Visually confirm vividness via the LumaDesignSystem previews
(`StrobeLab`, `DesignSystemGallery`) in light appearance.
