---
severity: medium
audit: 2026-06-12-full
finding: M2
status: closed
closed: 2026-06-14
---

# M2 — Lock Bloom Color Diverges from Other Lock Affordances Under Non-Default Palettes

**Decision (2026-06-14):** All lock affordances follow the palette everywhere.

**Fix applied:**
- `TunerVisualState.glow(palette:scheme:)` — new method returning palette-resolved tune colour
- `LiveTunerScreen` — `.lumaGlow(state.glow(palette:scheme:))` sets the environment for all consumers
- `NoteReadout` — reads `@Environment(\.lumaGlow)`; removed hardcoded `.lumaGlow(.lumaInTune)` override
- `CentsReadout`, `StateLine` — use env glow for `.tune` state, fixed tokens for flat/sharp/idle
- `Oscilloscope` — same pattern; glow passed into `draw` to avoid stale capture
- `StringCell` — reads `@Environment(\.lumaPalette)` + `@Environment(\.colorScheme)`, resolves `tuneColor` via `StrobePalette.resolve`
