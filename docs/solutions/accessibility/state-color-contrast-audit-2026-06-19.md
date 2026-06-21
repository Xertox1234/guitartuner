# State-color contrast audit — WCAG AA (2026-06-19)

> **Resolved 2026-06-21** (`P3-lightmode-palette-aa`, "two-tier" brand decision). The
> light-mode AA gap documented below is fixed: the small StateLine tag *text* now uses
> darker, text-safe colorset tokens (≥ 4.5:1) while the strobe *ribbons* stay vivid,
> nudged only enough to clear the 3:1 graphic threshold. Both `ContrastAuditTests`
> light-appearance tests are re-enabled and passing. New values + mechanism are in the
> **Resolution** section at the end of this file. The tables below are the original
> 2026-06-19 *pre-fix* measurements, preserved as the audit trail.

Source rule: `docs/rules/accessibility.md` (Contrast). Method: WCAG 2.x sRGB
relative-luminance ratio (see `ContrastAuditTests.swift`). Backgrounds: dark `#0A0B10`,
light `#E7EAF1` (confirmed from `Colors.xcassets/bg.colorset/Contents.json` and
`StrobePalette.resolve()` — bg is palette-agnostic).

Note (pre-fix): at audit time the `*.colorset` hexes and `StrobePalette.chroma(.aurora,
scheme)` primaries were identical, so the text-section and graphic-section ratios below
are the same six measurements — only the threshold differs (4.5 vs 3.0). **This parity
no longer holds for light aurora after the 2026-06-21 fix** — see Resolution.

## Asset-catalog state tokens (text, 4.5:1 threshold)

StateLine tag (`FLAT`/`SHARP`/`IN TUNE`) renders state-colored text at 10 pt mono
(normal text, NOT large text) on the app background.

| Token  | Appearance | Hex       | vs. bg    | Ratio   | AA text (4.5) | AA graphic (3.0) |
|--------|-----------|-----------|-----------|---------|---------------|------------------|
| flat   | dark       | #4D8BFF   | #0A0B10   | 6.04:1  | PASS          | PASS             |
| sharp  | dark       | #FFA53C   | #0A0B10   | 10.02:1 | PASS          | PASS             |
| inTune | dark       | #28F0C0   | #0A0B10   | 13.40:1 | PASS          | PASS             |
| flat   | light      | #2E6BFF   | #E7EAF1   | 3.74:1  | **FAIL**      | PASS             |
| sharp  | light      | #D9760F   | #E7EAF1   | 2.66:1  | **FAIL**      | **FAIL**         |
| inTune | light      | #07A07C   | #E7EAF1   | 2.76:1  | **FAIL**      | **FAIL**         |

## Strobe palette (graphics, 3:1) — StrobePalette.swift aurora primaries

Aurora strobe ribbons and large readout numerals (NoteReadout 168 pt / CentsReadout 30 pt —
large text) are classified as graphics/large text (3:1 threshold). Aurora flat/sharp/tune
primaries are byte-for-byte identical to the colorset hexes above; ratios are the same.

| Slot  | Appearance | Hex     | vs. bg  | Ratio   | AA graphic (3.0) |
|-------|-----------|---------|---------|---------|------------------|
| flat  | dark       | #4D8BFF | #0A0B10 | 6.04:1  | PASS             |
| sharp | dark       | #FFA53C | #0A0B10 | 10.02:1 | PASS             |
| tune  | dark       | #28F0C0 | #0A0B10 | 13.40:1 | PASS             |
| flat  | light      | #2E6BFF | #E7EAF1 | 3.74:1  | PASS             |
| sharp | light      | #D9760F | #E7EAF1 | 2.66:1  | **FAIL**         |
| tune  | light      | #07A07C | #E7EAF1 | 2.76:1  | **FAIL**         |

## Conclusion

**Dark mode meets WCAG AA throughout** — all three state tokens clear both thresholds
(text 4.5 and graphic 3.0) with significant margin (minimum 6.04:1).

**Light mode fails across all three state tokens for the text threshold (4.5:1):**
flat 3.74:1, sharp 2.66:1, inTune 2.76:1. Additionally, sharp and inTune fall below the
graphic threshold (3.0:1) at 2.66 and 2.76 respectively. Flat passes the graphic
threshold at 3.74:1.

**No token was changed.** A lightness-only fix (darkening the light-mode tokens) is
mathematically possible and hue-preserving, but it substantially mutes the vibrancy of
the signature brand colors — sharp orange (#D9760F → deep brown) and inTune teal
(#07A07C → dark teal) would shift away from their intended character. This is a
brand-palette decision: dark mode meets AA throughout; light-mode aurora state colors fall
below AA (text threshold for all three, graphic threshold for sharp and inTune). Surfaced
to the user; no token changed pending that decision.

### Failing ratios (prominently reported for brand decision)

| Token  | Metric           | Measured | Required | Gap       |
|--------|------------------|----------|----------|-----------|
| flat   | text 4.5 (light) | 3.74:1   | 4.5:1    | −0.76     |
| sharp  | text 4.5 (light) | 2.66:1   | 4.5:1    | −1.84     |
| inTune | text 4.5 (light) | 2.76:1   | 4.5:1    | −1.74     |
| sharp  | graphic 3.0 (light) | 2.66:1 | 3.0:1  | −0.34     |
| inTune | graphic 3.0 (light) | 2.76:1 | 3.0:1  | −0.24     |

The affected tests (`stateTextContrast_light`, `strobeGraphicContrast_light`) are marked
`@Test(.disabled(...))` in `ContrastAuditTests.swift` — they remain visible in the test
suite to prevent silent regression once the brand decision is made and the tokens are
updated.

---

## Resolution (2026-06-21) — two-tier light palette

Brand decision: **keep the strobe ribbons vivid, make the tag text readable.** Rather than
darkening every light token to the 4.5:1 text threshold (which would mute the signature
strobe), the light aurora palette is split into two tiers by WCAG element class:

- **Tag text (normal text, 4.5:1)** — the `flat`/`sharp`/`inTune` *colorset* tokens are
  darkened (hue-preserving: scaled by a constant factor in linear-RGB, so luminance drops
  while chromaticity holds up to 8-bit rounding):

  | Token  | Light: was → now | Ratio: was → now |
  |--------|------------------|------------------|
  | flat   | `#2E6BFF` → `#285EE2` | 3.74 → **4.60** |
  | sharp  | `#D9760F` → `#9F5508` | 2.66 → **4.62** |
  | inTune | `#07A07C` → `#04775B` | 2.76 → **4.59** |

- **Strobe ribbons (graphic, 3:1)** — `StrobePalette.chroma(.aurora, .light)` keeps the
  vivid hues, nudged only enough to clear 3:1; `flat` was already compliant:

  | Slot  | Light: was → now | Ratio: was → now |
  |-------|------------------|------------------|
  | flat  | `#2E6BFF` (unchanged) | 3.74 (already ≥ 3.0) |
  | sharp | `#D9760F` → `#C66B0D` | 2.66 → **3.16** |
  | tune  | `#07A07C` → `#069573` | 2.76 → **3.14** |

  `flat2`/`sharp2`/`tune2` were already ≥ 3.0 and are unchanged (ramp order preserved).

**Mechanism note — why the colorset and the strobe palette now diverge for light aurora.**
The audit measured the colorset as a proxy for the rendered tag, valid only while the two
sources were byte-identical. They are now intentionally different: the small StateLine tag
is *normal text* (4.5:1), the ribbon is a *graphic* (3:1). One code change makes the proxy
honest again — `StateLine` previously coloured the in-tune tag from the palette-resolved
glow (`state == .tune ? glow : state.glow`); it now uses `state.glow` (the `inTune`
colorset) for **all** states, so the in-tune tag is text-safe and palette-agnostic, exactly
like FLAT/SHARP. The vivid palette `tune` still drives the hero `NoteReadout` bloom and the
strobe ribbon (both graphics). Side effect: in **dark** mode the in-tune tag for *non-aurora*
palettes now uses the aurora `inTune` colorset rather than that palette's tune (dark passes
AA throughout, so this is cosmetic).

**Scope.** Aurora only — the signature/default palette the audit and the two tests cover.
The other four palettes (amber/neon/forest/crimson) almost certainly fail light AA too but
are untested and not CI-gated; tracked separately in `docs/todos/`.

Both `ContrastAuditTests` light tests are re-enabled (no longer `.disabled`) and pass; the
dark tests are unchanged and still pass.
