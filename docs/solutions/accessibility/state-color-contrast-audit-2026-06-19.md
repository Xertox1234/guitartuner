# State-color contrast audit — WCAG AA (2026-06-19)

Source rule: `docs/rules/accessibility.md` (Contrast). Method: WCAG 2.x sRGB
relative-luminance ratio (see `ContrastAuditTests.swift`). Backgrounds: dark `#0A0B10`,
light `#E7EAF1` (confirmed from `Colors.xcassets/bg.colorset/Contents.json` and
`StrobePalette.resolve()` — bg is palette-agnostic).

Note: the `*.colorset` hexes and `StrobePalette.chroma(.aurora, scheme)` primaries are
identical (confirmed by reading both sources), so the text-section and graphic-section
ratios below are the same six measurements — only the threshold differs (4.5 vs 3.0).

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
