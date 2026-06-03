# Fonts — drop-in slot

LUMA uses two open-licensed (OFL 1.1) typefaces. The Swift code resolves them by
**family name** at runtime and **falls back to SF Pro Display / SF Mono** if the
files aren't present — so the app builds and runs without them. Drop the files in
here to get the real LUMA look.

## Required files

| Role | Family | Weight(s) used | File(s) to add |
|---|---|---|---|
| Display / note / wordmark | **Chakra Petch** | 600 (SemiBold) | `ChakraPetch-SemiBold.ttf` |
| Numerals / labels / mono | **JetBrains Mono** | 400, 500 | `JetBrainsMono-Regular.ttf`, `JetBrainsMono-Medium.ttf` |

Add each typeface's **license file** alongside the fonts:

- `ChakraPetch-OFL.txt`
- `JetBrainsMono-OFL.txt`

> **Verify the license before bundling.** Both are SIL Open Font License 1.1 at
> time of writing; confirm the exact license shipped with the version you
> download and keep the `OFL.txt` next to the fonts.

## Where to get them

- Chakra Petch — Google Fonts (designer: Cadson Demak), OFL 1.1.
- JetBrains Mono — JetBrains, OFL 1.1.

Download the static `.ttf` files (not variable/web formats) for the weights above.

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
