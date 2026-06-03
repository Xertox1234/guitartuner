# Building LUMA

This repo holds the SwiftUI multiplatform app skeleton (`App/`) and the LUMA
design-system Swift package (`Packages/LumaDesignSystem/`). The Xcode project is
**generated from [`project.yml`](project.yml)** with [XcodeGen] so it stays
text-reviewable and reproducible (and isn't committed).

> Requires a Mac with **Xcode 15+** (targets iOS 17 / macOS 14). SwiftUI can't
> build on Linux, so the project is assembled and built on macOS.

## Quick start (the app)

```sh
brew install xcodegen          # one-time; needs XcodeGen >= 2.39
xcodegen generate              # creates LUMA.xcodeproj from project.yml
open LUMA.xcodeproj
```

Pick the **LUMA** scheme and run on an iOS Simulator or **My Mac**. The app opens
to a tab bar: the static **Tuner** screen and the **Design System** gallery (with
a dark/light/system theme toggle in the toolbar). No tuner/DSP logic yet — that's
Plan 01 (engine) and Plan 03 (strobe).

## Working on the design system only

You don't need the app to iterate on tokens/components — open the package directly
and use Xcode Previews:

```sh
open Packages/LumaDesignSystem/Package.swift
```

Every component and the gallery has `#Preview`s in **dark + light**. You can also
run the model tests:

```sh
cd Packages/LumaDesignSystem && swift test
```

## Fonts (optional, recommended)

LUMA uses **Chakra Petch** + **JetBrains Mono** (both OFL 1.1). They aren't
committed; the code falls back to **SF Pro Display / SF Mono** until you add them.
Drop the `.ttf` files (and their `OFL.txt`) into
[`Packages/LumaDesignSystem/Sources/LumaDesignSystem/Resources/Fonts/`](Packages/LumaDesignSystem/Sources/LumaDesignSystem/Resources/Fonts/README.md)
— `LumaFonts.registerIfNeeded()` registers them at launch. See that folder's
README for the exact filenames.

## Continuous integration

[`.github/workflows/ci.yml`](.github/workflows/ci.yml) runs on every push/PR on a
**macOS** runner: it `swift test`s the design-system package and builds the app
for **iOS Simulator + macOS** via `xcodegen generate` + `xcodebuild`. This is the
automated compile/test check (the scaffold was authored on Linux without a Swift
toolchain, so CI is the real verification).

## Layout

```
App/                         SwiftUI multiplatform app target (entry + root + Info.plist + app assets)
Packages/LumaDesignSystem/   the design system: tokens, modifiers, components, gallery
project.yml                  XcodeGen spec (source of truth for LUMA.xcodeproj)
docs/                        DESIGN.md, EXPERIENCE.md, design_reference/, plans/
```

## Notes

- **Not Mac Catalyst** — `supportedDestinations: [iOS, macOS]` builds a true
  multiplatform target.
- The app icon is a placeholder (no art yet — see `docs/design_reference/appicon.jsx`
  and DESIGN §10); a missing icon only warns.
- This scaffold was authored on Linux and **has not been compiled** — build it in
  Xcode on macOS and report any fixups.

[XcodeGen]: https://github.com/yonaskolb/XcodeGen
