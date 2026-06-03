# LumaDesignSystem

The **LUMA** design system translated to SwiftUI — tokens, the glow/bloom system,
a static (logic-free) component library, and a Design-System Gallery. Dark-first
and luminous: *depth comes from additive glow, not drop-shadows.*

Source of truth: [`docs/design_reference/DESIGN_SYSTEM.md`](../../docs/design_reference/DESIGN_SYSTEM.md)
and the CSS/JSX export beside it. **No audio/DSP** here (that's `TunerEngine`,
Plan 01) and **no strobe** (Plan 03) — just the visual language.

## Tokens

| Token | Type | API |
|---|---|---|
| Colour | asset catalog (Any/light + Dark) | `LumaColor` · `Color.luma*` |
| Type | Chakra Petch / JetBrains Mono / System | `LumaFont.display/.mono/.ui`, `LumaFont.Size` |
| Spacing | 4pt rhythm | `Space.s1…s12` |
| Radius | 8…40 + full | `Radius.r1…r6`, `Radius.full` |
| Tracking | em → points | `Tracking`, `.lumaTracking(_:size:)` |
| Glow | additive bloom | `.bloom(.l1/.l2/.l3/.text)`, `.lumaGlow(_:)`, `FieldWash`, `ScreenBackground` |

Colours resolve via the system appearance; the app exposes a manual override
(`@AppStorage("theme")`).

## Components

`Brand` · `NoteReadout` · `CentsReadout` · `StateLine` · `FreqLine` · `TargetChip`
· `StringRow` · `A4Control` · `InputSource` · `ToneToggle` · `SettingsButton` ·
`ScreenTop` · `ControlsDock` · `TunerScreenStatic`.

Each has `#Preview`s in dark + light with hard-coded states. The full screen is
`TunerScreenStatic(note:octave:cents:)` (`cents: nil` = idle/standby).

## Usage

```swift
import LumaDesignSystem

struct Demo: View {
    @State private var a4 = 440
    var body: some View {
        VStack(spacing: Space.s5) {
            NoteReadout(note: "E", octave: 4, locked: true)
            CentsReadout(cents: 0, state: .tune)
            A4Control(a4: $a4)
        }
        .lumaGlow(.tune)            // sets the active glow hue
        .background(ScreenBackground())
    }
}
```

## Fonts

Custom faces are optional — see
[`Sources/LumaDesignSystem/Resources/Fonts/README.md`](Sources/LumaDesignSystem/Resources/Fonts/README.md).
Call `LumaFonts.registerIfNeeded()` at launch; without the files, type falls back
to SF Pro Display / SF Mono.
