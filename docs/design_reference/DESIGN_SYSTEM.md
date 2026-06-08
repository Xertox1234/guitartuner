# LUMA — Design System

Authoritative spec **reconciled from the Claude Design export** in this folder
(`ds-tokens.css`, `ds-components.css`, `tuner-ui.jsx`, `strobe-*.jsx`,
`foundations.jsx`). This is the bridge the native **SwiftUI** build translates from.

> Aesthetic in one line: **dark-first and luminous — depth comes from additive
> glow, not drop-shadows; the strobe is the hero; the in-tune state is sacred;
> error is never encoded by colour alone.**

---

## Decisions locked — 2026-06-03

| Decision | Resolution |
|---|---|
| **Product name** | **LUMA** |
| **Hero visualizer** | Ship **both** strobes, **user-selectable**. Default **Aurora Ribbons**; **Radial Phase Ring** offered in Settings. |
| **Reduced motion** | Position-encoded **gauge** (needle + arc), engaged automatically when OS *Reduce Motion* is on — an equal, not a downgrade. |
| **Oscilloscope** | **Carried over** from the alternate exploration as an *optional* secondary "scope" (live waveform), **restyled into LUMA tokens**. |
| **Input** | **DI-first** — source defaults to DI; mic is the alternate. |

---

## Tokens

### Type
| Role | Family | Notes |
|---|---|---|
| Display / note / wordmark | **Chakra Petch** 600 | hero note renders at **168px** |
| Numerals / labels / mono | **JetBrains Mono** | `tabular-nums`, tracking `0.04em` — cents·Hz·A4 never jitter |
| UI / body | system (`-apple-system` / SF Pro Text) | Dynamic-Type feel |

Scale (px): `11 · 12 · 13 · 15 · 17 · 20 · 24 · 32 · 44 · 56 (num) · 72 · 168 (note)`

### Colour — dark (default)
| Token | Hex |
|---|---|
| `bg` / `bg-grad` | `#0A0B10` / `#0D0F18` |
| `surface` / `-2` / `-3` | `#14161F` / `#1B1E2A` / `#242838` |
| `ink` / `dim` / `faint` | `#EEF1F8` / `#8E94A6` / `#565C70` |
| `line` / `line-2` | `rgba(255,255,255,.07)` / `.13` |
| **FLAT** (+companion) | **`#4D8BFF`** electric blue (+`#8A6BFF` violet) |
| **SHARP** (+companion) | **`#FFA53C`** amber (+`#FF6A4D` coral) |
| **IN-TUNE · SACRED** (+deep) | **`#28F0C0`** mint (+`#16C8A0`) |
| `brand-glow` | `#28F0C0` |

### Colour — light
`bg #E7EAF1` · `surface #FFFFFF` · `ink #0D0F16` · `dim #565D6E` · `faint #9AA1B2`
· FLAT `#2E6BFF` · SHARP `#D9760F` · **IN-TUNE `#07A07C`** (deepened to hold on white)
· `brand-glow #1FD9AC`

### Spacing · Radius · Glow
- **Spacing (4pt):** `2 · 4 · 8 · 12 · 16 · 20 · 24 · 32 · 40 · 48 · 64 · 80`
- **Radius:** `8 · 12 · 16 · 20 · 28 · 40 · full`
- **Glow/bloom:** `bloom-1/2/3` layer a tight core + soft outer bloom in the active
  hue (`color-mix` in oklab); `bloom-text` is the locked-note reward; `field-wash`
  is the soft radial behind the hero.

---

## Behaviour

- **Lock:** `|cents| < 3.0¢` → note flips to **sacred mint + text bloom**, strobe
  **freezes and blooms**. Full-scale error window `±50¢`.
- **States** (colour **+** sign **+** arrow **+** motion **+** text):
  | State | Text | Cue |
  |---|---|---|
  | idle | `STANDBY · pluck a string` | dimmed note |
  | flat (−) | `FLAT · tune up` | ▲ + blue |
  | sharp (+) | `SHARP · tune down` | ▼ + amber |
  | in tune | `IN TUNE · hold it` | mint + bloom |
- **Freq line:** `<Hz> · <ALGO> · <rate>` (e.g. `146.8 Hz · YIN · 48k`).

---

## Layout (top → bottom)

1. **Top chrome** — brand (LUMA dot + wordmark) · input source (DI/MIC) · settings.
2. **Hero field** — full-bleed strobe (Aurora | Radial | Reduced) behind a centered
   note stack: note + octave, signed cents (▲▼), state line, freq line.
   *Optional* oscilloscope scope (toggle).
3. **Dock** — target chip (Auto chromatic | String lock) · string row · A4 control
   (430–450 Hz, default 440) · tone-generator toggle.

### Instruments
- **Guitar:** E2 A2 D3 G3 B3 E4 — midi `40 45 50 55 59 64`
- **Bass:** E1 A1 D2 G2 — midi `28 33 38 43`

---

## SwiftUI translation notes

- **Tokens →** a `DesignTokens` namespace (`Color` / `Font` / `CGFloat`) backed by a
  **Color asset catalog** with dark+light variants, so the system resolves theme.
- **Fonts →** bundle Chakra Petch + JetBrains Mono and register in `Info.plist`
  (fall back to SF Pro Display / SF Mono if we choose to avoid custom fonts).
- **Strobes →** the hero strobe targets **Metal** (`StrobeRenderer`, per `DESIGN.md` §5)
  for 120 fps additive blending — Aurora = gradient ribbons, Radial = rotating phase marks,
  both freeze + bloom at lock. `Canvas` + `TimelineView` is the viable prototype/fallback
  path. Variant stored in `@AppStorage`; the reduced-motion gauge honours
  `accessibilityReduceMotion`.
- **Glow/bloom →** layered blur/`.shadow` or additive `Canvas` blend — *luminosity,
  not shadows*.
- **Oscilloscope →** optional view fed by the same audio frames; recolour to
  `flat`/`sharp`/`in-tune` + glow.

---

## Provenance / file map

| Status | Files |
|---|---|
| **Canonical (LUMA)** | `ds-tokens.css`, `ds-components.css`, `tuner-ui.jsx`, `strobe-core/aurora/radial/reduced.jsx`, `foundations.jsx`, `Tuner Design System.html` |
| **Reference** | `screenshots/` — the canonical LUMA concept boards (`phones-a/b`, `check-01/02`). |

> The earlier "modular-synth / stomp-box" exploration (`styles.css`, `visualizer.jsx`,
> `oscilloscope.jsx`, `tuner.jsx`, `ios-frame.jsx`, `index.html`) was removed once
> superseded by LUMA; its one carried-over idea, the live oscilloscope, now lives as
> [`Components/Oscilloscope.swift`](../../Packages/LumaDesignSystem/Sources/LumaDesignSystem/Components/Oscilloscope.swift) in LUMA tokens.
