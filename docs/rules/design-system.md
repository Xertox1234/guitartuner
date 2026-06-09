# Design system rules

- **Dark-first.** The light mode palette is secondary. Design and test dark first; light mode follows.
- Glow uses **additive bloom** (`.bloom()` modifier), never drop-shadows. Elevation is expressed through light, not shadow.
- `LumaColor` resolves via the asset catalog for both appearances automatically. Do not hardcode hex values or use `Color(red:green:blue:)` for brand colors.
- Fonts: `LumaFont.display` (Chakra Petch) for note names and headings; `LumaFont.mono` (JetBrains Mono) for cents and frequency readouts. Fallback to SF Pro Display / SF Mono is automatic if fonts fail to register — do not break the fallback.
- Use **tabular (monospaced-digit)** font for any number that updates live. This prevents layout jitter as digits change width. `LumaFont.mono` provides this.
- `LumaDesignSystem` has no dependency on `TunerEngine` and must never gain one.
- Every new component requires `#Preview`s in **both dark and light**. Do not add a component without previews.
- Use `Space`, `Radius`, and `Tracking` tokens for spacing/radius/letter-spacing. Do not invent custom numeric values.
- State accent colors are fixed: `LumaColor.tune` (sacred mint) = in-tune, `LumaColor.sharp` (amber) = sharp, `LumaColor.flat` (blue) = flat. Do not introduce new state colors without explicit design decision.
- `ScreenChrome` / `ControlsDock` / `StageView` are layout containers — keep them layout-only with no business logic.
