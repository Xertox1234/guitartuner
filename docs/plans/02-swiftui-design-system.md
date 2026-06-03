# Plan 02 — SwiftUI design-system scaffold (LUMA tokens + components)

> Execute in its own session. Stands up the app skeleton and translates the **LUMA** design
> system into SwiftUI — tokens + a static component library matching the export.

## Goal
The SwiftUI multiplatform app project plus a **`DesignSystem`** layer: every LUMA token as
code (colours dark/light, type, spacing, radius, glow) and the static, previewable
**component library** that matches `docs/design_reference/` — **no tuner logic yet.**

## Prerequisites & references
- `docs/design_reference/DESIGN_SYSTEM.md` — the token tables (source of truth)
- `docs/design_reference/ds-tokens.css`, `ds-components.css`, `tuner-ui.jsx` — exact values
  + component structure
- `docs/design_reference/screenshots/` — the visual target (dark + light)
- `DESIGN.md` §5 — stack: SwiftUI multiplatform, **not** Catalyst

## In scope
App skeleton · colour asset catalog · fonts · token helpers · glow modifier · static
components · a Design-System Gallery screen.

## Out of scope
Audio/DSP · live state · the strobe (Plan 03) · settings logic.

## Plan

### 1. App skeleton
One **SwiftUI multiplatform** app target (iPhone/iPad/Mac). Suggested groups: `App/`,
`DesignSystem/` (Tokens, Components, Modifiers), `Resources/` (Fonts, Assets), `Features/`
(empty for now). Consider a local `DesignSystem` Swift package for isolation.

### 2. Colours → Asset Catalog (dark + light)
- One colour set per token with **Any (light)** + **Dark** appearances. Tokens + hex come
  straight from `DESIGN_SYSTEM.md`:
  - neutrals: `bg, bgGrad, surface, surface2, surface3, ink, dim, faint, line, line2`
  - signal: `flat, flat2, sharp, sharp2, inTune, inTune2, brandGlow`
- Expose as `enum LumaColor` / a `Color` extension. Theme resolves via the system; allow a
  manual override later (`@AppStorage("theme")`).

### 3. Typography
- Bundle **Chakra Petch** (display/note) + **JetBrains Mono** (numerals) `.ttf`; register via
  `UIAppFonts` / `ATSApplicationFontsPath`. Both are **open-licensed (OFL)** — include the
  licence files; verify before bundling.
- `enum LumaFont` for the scale (note 168, num 56, 2xl…micro). **Tabular numerals** everywhere
  via `.monospacedDigit()` / font feature. Fallbacks: SF Pro Display / SF Mono.

### 4. Spacing · Radius · Glow
- `enum Space` (4pt: 2…80) and `enum Radius` (8…40, full) as `CGFloat`.
- `.bloom(_ level:)` `ViewModifier` — layered blur / `.shadow` (or compositing) in the active
  hue; **luminosity, not drop-shadows.** Plus a `fieldWash` radial background.

### 5. Static component library (port from `tuner-ui.jsx`, recoloured to tokens)
`NoteReadout` · `CentsReadout` (signed, tabular, ▲▼) · `StateLine`
(STANDBY/FLAT/SHARP/IN TUNE) · `FreqLine` · `TargetChip` (Auto/String) · `StringRow` ·
`A4Control` (430–450) · `InputSource` (DI/MIC) · `ToneToggle` · `Brand` · top chrome · dock.
Each with `#Preview` in **dark + light**, hard-coded states (no logic).

### 6. Design-System Gallery
A scrollable screen (the `foundations.jsx` equivalent): colour swatches, type scale,
spacing/radius, glow levels, and the component library — the visual-regression target vs the
screenshots.

## Definition of done
App builds & runs on iOS + macOS; fonts render; the Gallery matches the export screenshots in
dark + light; components are previewable and reusable.

## Open questions (resolve in-session)
Xcode-project vs SPM-first layout · whether to factor `DesignSystem` as a separate package ·
custom fonts vs SF-only · minimum OS (align with the engine).

## Kickoff prompt
> Read `DESIGN.md`, `docs/EXPERIENCE.md`, `docs/design_reference/DESIGN_SYSTEM.md`, and
> `docs/plans/02-swiftui-design-system.md`. Scaffold the SwiftUI multiplatform app + the LUMA
> design system: colour asset catalog (dark+light) for every token, Chakra Petch + JetBrains
> Mono registered, `LumaFont`/`Space`/`Radius` helpers, the `.bloom` modifier, and the static
> component library with a Design-System Gallery matching the export screenshots. No tuner
> logic.
