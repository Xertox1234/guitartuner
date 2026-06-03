# Fonts — bundled

LUMA uses two open-licensed (OFL 1.1) typefaces, **vendored here** and resolved
by **family name** at runtime. The Swift code still **falls back to SF Pro
Display / SF Mono** if the files are ever absent — so the app always builds and
runs.

## Bundled files

| Role | Family | Weight(s) | File |
|---|---|---|---|
| Display / note / wordmark | **Chakra Petch** | 600 (SemiBold) | `ChakraPetch-SemiBold.ttf` |
| Numerals / labels / mono | **JetBrains Mono** | 400, 500 | `JetBrainsMono-Regular.ttf`, `JetBrainsMono-Medium.ttf` |

Each typeface's SIL Open Font License 1.1 ships alongside it:

- `ChakraPetch-OFL.txt`
- `JetBrainsMono-OFL.txt`

## Provenance

Vendored as the canonical static `.ttf` instances (not variable/web formats):

- **Chakra Petch** (designer: Cadson Demak) — `google/fonts` (`ofl/chakrapetch/`), OFL 1.1.
- **JetBrains Mono** — `JetBrains/JetBrainsMono` (`fonts/ttf/`), OFL 1.1.

> To refresh: re-pull the same `.ttf`s + their `OFL.txt` from the sources above.
> The registered family names must stay `Chakra Petch` / `JetBrains Mono` to
> match `LumaFont.displayFamily` / `LumaFont.monoFamily` (verified: nameID 1 /
> typographic family resolve to those).

## How registration works

These fonts live in the **package resource bundle**, not the app's `Info.plist`,
so they're registered programmatically by `LumaFonts.registerIfNeeded()` (called
from `LumaApp.init`). `Bundle.module` scans this `Fonts/` directory for `.ttf` /
`.otf` and registers each with Core Text. No `Info.plist` `UIAppFonts` entry is
needed for the package path.

If you instead add the fonts to the **app target**, list them under
`UIAppFonts` (iOS) / `ATSApplicationFontsPath` (macOS) in `App/Info.plist`.

After adding files, confirm the family names match `LumaFont.displayFamily`
("Chakra Petch") and `LumaFont.monoFamily` ("JetBrains Mono").
