---
severity: medium
audit: 2026-06-12-full
finding: M2
---

# M2 — Lock Bloom Color Diverges from Other Lock Affordances Under Non-Default Palettes

Under non-aurora palettes (amber, neon, etc.), the strobe bloom adopts the palette's tune hue
while every other lock affordance (`.lumaGlow`, `ReducedGauge` ring, `StringRow` lock indicator)
remains fixed-mint. Only visible with a non-default palette active.

**Affected files:**
- `LumaDesignSystem/Strobe/AuroraStrobe.swift` (line 139)
- `LumaDesignSystem/Strobe/RadialStrobe.swift` (line 151)
- `LumaDesignSystem/Strobe/MetalStrobe.swift` (`colTune` uniform)
- `LumaDesignSystem/Components/StringRow.swift` (lock color)
- `LUMA/App/LiveTunerScreen.swift` (`.lumaGlow`)

**Decision needed:** Is the divergence intentional (strobe follows palette, chrome follows
app theme), or should all lock affordances track the palette? If the latter, extend
`LumaColor.tune` / `LumaGlow` to derive from `@Environment(\.lumaPalette)`.
