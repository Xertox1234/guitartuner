---
severity: medium
audit: 2026-06-12-full
finding: M1
---

# M1 — ReducedGauge Not Palette-Threaded

`ReducedGauge` was missed when LumaPalette was wired through Aurora/Metal/Radial (89ed14c).
It hardcodes `.lumaInTune`, `.lumaFlat`, `.lumaSharp` with no `@Environment(\.lumaPalette)`.
Users with `accessibilityReduceMotion` never see the chosen palette.

**File:** `LumaDesignSystem/Strobe/ReducedGauge.swift` (lines 41–43, 68, 80)

**Fix:** Add `@Environment(\.lumaPalette) private var palette` and resolve colors from
`StrobePalette.resolve(scheme, palette: palette).tune` (and `.flat`/`.sharp` equivalents).

**Tests:** `swift test --package-path Packages/LumaDesignSystem` — add a parity test
asserting ReducedGauge resolves the same tune color as AuroraStrobe under a non-aurora palette.
