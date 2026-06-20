# Accessibility Code Conformance (C-1…C-4) Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Make `LumaDesignSystem` + `App/` code conform to the four accessibility rules `docs/rules/accessibility.md` already mandates (Reduce Transparency, Dynamic Type, contrast + color independence, photosensitivity), then archive the four backlog todos.

**Architecture:** Same shape as sub-project 2 (security code conformance, PR #51): the rules already exist; the code catches up. Most work is in `Packages/LumaDesignSystem` (its own `swift test` + Previews); C-2 also touches `App/` chrome consumers (needs the Xcode build). Translucency attenuation (C-1) and the WCAG contrast check (C-3) are extracted as **pure, testable** units so the tests are genuine, not hollow. C-4 is **analysis-gated**: an analysis task decides whether a code mitigation is dispatched.

**Tech Stack:** Swift 6 (strict concurrency), SwiftUI, SwiftPM, Swift Testing (`@Test`/`#expect`), XcodeGen, `xcodebuild`.

## Global Constraints

- **No rule behaviour changes** — `accessibility.md` already mandates all four behaviours; this plan only makes code conform. No edits to `docs/rules/accessibility.md`.
- **No networking changes; no DSP changes.** Package boundaries hold: `LumaDesignSystem` imports no `TunerEngine`/DSP; `TunerEngine` imports no UI.
- **Swift Concurrency only** (`async/await`, `actor`, `AsyncStream`); no Combine. No force-unwrapping in production paths.
- **New tests use Swift Testing** (`import Testing`, `@Suite`/`@Test`/`#expect`, `@testable import LumaDesignSystem`) — matches `Tests/LumaDesignSystemTests/LumaPaletteTests.swift`; do not add XCTest files.
- **Never break CI** — `swift test` (both packages) and the accuracy benchmark stay green; `./scripts/ci-invariants.sh` stays **0 HARD / 0 REVIEW** (no security regressions).
- **Color adjustments are hue-preserving only.** If a contrast token fails, change **lightness only** (documented); any change that shifts the brand hue is **surfaced to the user**, never made silently. The strobe palette (`StrobePalette.swift`) follows the same rule — audit + document, no silent retune.
- **No new invariant gates** — the invariant lib is security-only and accessibility can't be reliably grep-gated (decision recorded in the spec, "Gate promotion").
- **C-4 (analysis + any Metal mitigation) is strobe/Metal work** — most-capable model, strobe-specialist review, never delegated to a cheap worker. Sequenced last.
- **Verification is per-finding** (spec "verification model"): pure-helper unit tests (C-1, C-3, C-4b), documented measurement (C-3 contrast), previews + code review (C-2), analysis writeup (C-4a). Do **not** manufacture hollow asserts to fit a TDD template.

**Build/test commands (exact):**
- DS package tests: `swift test --package-path Packages/LumaDesignSystem`
- A single DS test: `swift test --package-path Packages/LumaDesignSystem --filter <Suite/test>`
- macOS app build: `xcodebuild build -project LUMA.xcodeproj -scheme LUMA -destination 'platform=macOS' CODE_SIGNING_ALLOWED=NO`
- iOS app build: `xcodebuild build -project LUMA.xcodeproj -scheme LUMA -destination 'generic/platform=iOS Simulator' CODE_SIGNING_ALLOWED=NO`
- Invariant scan: `./scripts/ci-invariants.sh`

---

## File Structure

| File | Change | Task |
|------|--------|------|
| `Packages/LumaDesignSystem/Sources/LumaDesignSystem/Modifiers/Translucency.swift` | **Create** — pure attenuation helper | C-1 |
| `…/Modifiers/Bloom.swift` | Modify — read Reduce Transparency, route opacities through helper, trait-on preview | C-1 |
| `…/Modifiers/FieldWash.swift` | Modify — same for `FieldWash` + `ScreenBackground`, trait-on previews | C-1 |
| `Packages/LumaDesignSystem/Tests/LumaDesignSystemTests/TranslucencyTests.swift` | **Create** — assert `attenuated < base` when trait on | C-1 |
| `…/Tokens/LumaFont.swift` | Modify — `relativeTo:` on `display`/`mono`, fix `ui` doc-comment | C-2 |
| `…/Modifiers/ScaledUIFont.swift` | **Create** — `@ScaledMetric` `.lumaUIFont(_:)` modifier for system chrome | C-2 |
| App chrome views + DS chrome components (enumerated in Task 2) | Modify — migrate to scaling fonts | C-2 |
| `Packages/LumaDesignSystem/Tests/LumaDesignSystemTests/ContrastAuditTests.swift` | **Create** — WCAG ratio helper + AA assertions over the design tokens | C-3 |
| `docs/solutions/accessibility/state-color-contrast-audit-2026-06-19.md` | **Create** — documented ratios (both appearances) | C-3 |
| `…/Components/StringRow.swift` | Modify — pure a11y-label helper incl. lock state, `differentiateWithoutColor` cue, trait-on preview | C-3 |
| `Packages/LumaDesignSystem/Tests/LumaDesignSystemTests/StringRowA11yTests.swift` | **Create** — assert the label includes the lock/active state | C-3 |
| `docs/solutions/accessibility/strobe-photosensitivity-2026-06-19.md` | **Create** — WCAG 2.3.1 analysis writeup | C-4a |
| `docs/rules/strobe.md` | Modify — one-line note recording the check | C-4a |
| `…/Strobe/StrobeMath.swift` (+ renderers incl. Metal) | Modify — **only if 4a finds a hazard** — flash-rate/luminance clamp | C-4b |
| `docs/todos/{P2-reduce-transparency,P2-dynamic-type-chrome,P2-contrast-color-independence,P3-strobe-photosensitivity-check}.md` | `git mv` → `docs/todos/archive/` | Wrap-up |

---

## Task 1: C-1 — Honor Reduce Transparency (bloom + washes)

**Files:**
- Create: `Packages/LumaDesignSystem/Sources/LumaDesignSystem/Modifiers/Translucency.swift`
- Create: `Packages/LumaDesignSystem/Tests/LumaDesignSystemTests/TranslucencyTests.swift`
- Modify: `Packages/LumaDesignSystem/Sources/LumaDesignSystem/Modifiers/Bloom.swift`
- Modify: `Packages/LumaDesignSystem/Sources/LumaDesignSystem/Modifiers/FieldWash.swift`

**Interfaces:**
- Produces: `enum Translucency { static func attenuated(_ base: Double, reduceTransparency: Bool) -> Double }` — returns `0` when the trait is on, `base` otherwise (the single source of truth for translucency policy). Both modifiers route every glow/wash opacity through it.

- [ ] **Step 1: Write the failing test**

Create `Packages/LumaDesignSystem/Tests/LumaDesignSystemTests/TranslucencyTests.swift`:

```swift
import Testing
@testable import LumaDesignSystem

@Suite("Reduce Transparency attenuation")
struct TranslucencyTests {
    @Test("passes the base opacity through when the trait is off")
    func passthrough() {
        #expect(Translucency.attenuated(0.55, reduceTransparency: false) == 0.55)
        #expect(Translucency.attenuated(0.16, reduceTransparency: false) == 0.16)
    }

    @Test("removes translucency when the trait is on")
    func attenuated() {
        // Every translucent layer collapses to fully transparent; the solid
        // base treatment underneath carries legibility.
        for base in [0.09, 0.16, 0.22, 0.45, 0.55, 0.70] {
            #expect(Translucency.attenuated(base, reduceTransparency: true) < base)
            #expect(Translucency.attenuated(base, reduceTransparency: true) == 0)
        }
    }
}
```

- [ ] **Step 2: Run the test to verify it fails**

Run: `swift test --package-path Packages/LumaDesignSystem --filter "Reduce Transparency attenuation"`
Expected: FAIL to **compile** — `Cannot find 'Translucency' in scope`.

- [ ] **Step 3: Create the pure helper**

Create `Packages/LumaDesignSystem/Sources/LumaDesignSystem/Modifiers/Translucency.swift`:

```swift
import Foundation

/// Single source of truth for the Reduce Transparency policy. Additive bloom and
/// the radial glow washes are *translucency*; when `accessibilityReduceTransparency`
/// is on, Apple HIG asks apps to drop blur/translucency in favour of solid
/// treatments. Every translucent layer routes its opacity through here so the
/// behaviour is uniform and unit-testable (the modifiers stay thin).
///
/// Kept free of SwiftUI so it's testable headlessly.
enum Translucency {
    /// The opacity a translucent layer should use. Collapses to fully
    /// transparent under Reduce Transparency (the opaque base treatment beneath
    /// — solid text, the solid canvas gradient — preserves legibility).
    static func attenuated(_ base: Double, reduceTransparency: Bool) -> Double {
        reduceTransparency ? 0 : base
    }
}
```

- [ ] **Step 4: Run the test to verify it passes**

Run: `swift test --package-path Packages/LumaDesignSystem --filter "Reduce Transparency attenuation"`
Expected: PASS (2 tests).

- [ ] **Step 5: Route Bloom through the helper**

In `…/Modifiers/Bloom.swift`, add the environment read and route every shadow opacity through `Translucency.attenuated`. Replace the `BloomModifier` struct (lines 49–74) with:

```swift
struct BloomModifier: ViewModifier {
    let level: BloomLevel
    @Environment(\.lumaGlow) private var glow
    @Environment(\.accessibilityReduceTransparency) private var reduceTransparency

    private func a(_ base: Double) -> Double {
        Translucency.attenuated(base, reduceTransparency: reduceTransparency)
    }

    @ViewBuilder
    func body(content: Content) -> some View {
        switch level {
        case .l1:
            content
                .shadow(color: glow.opacity(a(0.55)), radius: 2)
        case .l2:
            content
                .shadow(color: glow.opacity(a(0.60)), radius: 3)
                .shadow(color: glow.opacity(a(0.30)), radius: 8)
        case .l3:
            content
                .shadow(color: glow.opacity(a(0.70)), radius: 4)
                .shadow(color: glow.opacity(a(0.40)), radius: 12)
                .shadow(color: glow.opacity(a(0.22)), radius: 28)
        case .text:
            content
                .shadow(color: glow.opacity(a(0.45)), radius: 6)
                .shadow(color: glow.opacity(a(0.25)), radius: 20)
        }
    }
}
```

- [ ] **Step 6: Add a Reduce-Transparency Bloom preview**

In `…/Modifiers/Bloom.swift`, inside the `#if DEBUG` block (after the existing `#Preview`), add:

```swift
#Preview("Bloom levels — reduce transparency") {
    HStack(spacing: 30) {
        ForEach([BloomLevel.l1, .l2, .l3], id: \.self) { level in
            RoundedRectangle(cornerRadius: Radius.r3)
                .fill(Color.lumaInTune)
                .frame(width: 60, height: 60)
                .bloom(level)
        }
    }
    .lumaGlow(.lumaInTune)
    .padding(60)
    .frame(maxWidth: .infinity, maxHeight: .infinity)
    .background(Color.lumaBg)
    .environment(\.accessibilityReduceTransparency, true)
    .preferredColorScheme(.dark)
}
```

- [ ] **Step 7: Route FieldWash + ScreenBackground through the helper**

In `…/Modifiers/FieldWash.swift`:

In `FieldWash` (struct at line 6), add the trait read and attenuate the glow stop. Replace the `glow` environment line and the gradient's first stop:

```swift
public struct FieldWash: View {
    @Environment(\.lumaGlow) private var glow
    @Environment(\.accessibilityReduceTransparency) private var reduceTransparency

    public init() {}

    public var body: some View {
        GeometryReader { geo in
            let maxDim = max(geo.size.width, geo.size.height)
            RadialGradient(
                gradient: Gradient(stops: [
                    .init(color: glow.opacity(Translucency.attenuated(0.16, reduceTransparency: reduceTransparency)), location: 0),
                    .init(color: .clear, location: 0.72)
                ]),
                center: UnitPoint(x: 0.5, y: 0.42),
                startRadius: 0,
                endRadius: maxDim * 0.6
            )
        }
    }
}
```

In `ScreenBackground` (struct at line 37), add the trait read and attenuate **only the ambient glow wash** (the base canvas `bg-grad → bg` is opaque and must stay). Replace the struct body:

```swift
public struct ScreenBackground: View {
    @Environment(\.lumaGlow) private var glow
    @Environment(\.accessibilityReduceTransparency) private var reduceTransparency

    public init() {}

    public var body: some View {
        GeometryReader { geo in
            let maxDim = max(geo.size.width, geo.size.height)
            ZStack {
                // Base canvas: opaque — stays under Reduce Transparency.
                RadialGradient(
                    gradient: Gradient(stops: [
                        .init(color: .lumaBgGrad, location: 0),
                        .init(color: .lumaBg, location: 0.6)
                    ]),
                    center: UnitPoint(x: 0.5, y: -0.1),
                    startRadius: 0,
                    endRadius: maxDim * 1.2
                )
                // Ambient glow wash: translucency — removed under Reduce Transparency.
                RadialGradient(
                    gradient: Gradient(stops: [
                        .init(color: glow.opacity(Translucency.attenuated(0.09, reduceTransparency: reduceTransparency)), location: 0),
                        .init(color: .clear, location: 0.7)
                    ]),
                    center: UnitPoint(x: 0.5, y: 0.38),
                    startRadius: 0,
                    endRadius: maxDim * 0.55
                )
                .animation(.easeInOut(duration: 0.6), value: glow)
            }
        }
        .ignoresSafeArea()
    }
}
```

- [ ] **Step 8: Add Reduce-Transparency wash previews**

In `…/Modifiers/FieldWash.swift`, inside the `#if DEBUG` block, add:

```swift
#Preview("Screen background — reduce transparency") {
    ScreenBackground()
        .lumaGlow(.lumaInTune)
        .environment(\.accessibilityReduceTransparency, true)
        .preferredColorScheme(.dark)
}

#Preview("Field wash — reduce transparency (light)") {
    FieldWash()
        .lumaGlow(.lumaSharp)
        .frame(width: 320, height: 480)
        .background(Color.lumaBg)
        .environment(\.accessibilityReduceTransparency, true)
        .preferredColorScheme(.light)
}
```

- [ ] **Step 9: Run the full DS test suite**

Run: `swift test --package-path Packages/LumaDesignSystem`
Expected: PASS — all existing tests + the 2 new `TranslucencyTests`.

- [ ] **Step 10: Commit**

```bash
git add Packages/LumaDesignSystem/Sources/LumaDesignSystem/Modifiers/Translucency.swift \
        Packages/LumaDesignSystem/Sources/LumaDesignSystem/Modifiers/Bloom.swift \
        Packages/LumaDesignSystem/Sources/LumaDesignSystem/Modifiers/FieldWash.swift \
        Packages/LumaDesignSystem/Tests/LumaDesignSystemTests/TranslucencyTests.swift
git commit -m "feat(a11y): honor Reduce Transparency in bloom + washes (C-1)"
```

---

## Task 2: C-2 — Scale chrome/settings text with Dynamic Type

**Model:** most-capable — the cross-platform font-scaling mechanism (custom `relativeTo:` vs. system `@ScaledMetric`) is the subtlest decision in the sub-project.

**Files:**
- Modify: `Packages/LumaDesignSystem/Sources/LumaDesignSystem/Tokens/LumaFont.swift`
- Create: `Packages/LumaDesignSystem/Sources/LumaDesignSystem/Modifiers/ScaledUIFont.swift`
- Modify (chrome consumers — full list below)

**Interfaces:**
- Consumes: nothing from earlier tasks.
- Produces:
  - `LumaFont.display(_:weight:relativeTo:)` and `LumaFont.mono(_:weight:relativeTo:)` — new optional `relativeTo textStyle: Font.TextStyle? = nil`; `nil` = fixed (the existing behaviour, used by the opt-out instrument readout), non-`nil` = scales.
  - `View.lumaUIFont(_ size: CGFloat, weight: Font.Weight = .regular, relativeTo: Font.TextStyle = .body) -> some View` — a `@ScaledMetric`-backed system font for chrome (a system font cannot carry `relativeTo:`, so scaling happens at the view).

**Opt-out rule (apply precisely):** only the **large instrument numerals** stay fixed — `NoteReadout`'s note name + accidental and `CentsReadout`'s big signed number. Every other text site scales: settings/account/store chrome, DS chrome components, the state line, string-row labels, and the dock readouts. *(This refines the spec's consumer grouping per the audit's WCAG 1.4.4 rationale — the "primary instrument readout that may opt out" is the huge numerals, not every small label near them. The opt-out sites carry a comment.)*

- [ ] **Step 1: Add `relativeTo:` to the custom-font builders**

In `…/Tokens/LumaFont.swift`, replace `display` (lines 41–46) and `mono` (lines 49–54):

```swift
    /// Display face (Chakra Petch), falling back to SF Pro Display. Pass
    /// `relativeTo:` to scale with Dynamic Type; omit it for a fixed size
    /// (the deliberate opt-out for the full-bleed instrument readout).
    public static func display(_ size: CGFloat, weight: Font.Weight = .semibold,
                               relativeTo textStyle: Font.TextStyle? = nil) -> Font {
        if isAvailable(displayFamily) {
            if let textStyle {
                return Font.custom(displayFamily, size: size, relativeTo: textStyle).weight(weight)
            }
            return Font.custom(displayFamily, size: size).weight(weight)
        }
        return .system(size: size, weight: weight, design: .default)
    }

    /// Mono face (JetBrains Mono) with tabular digits, falling back to SF Mono.
    /// Pass `relativeTo:` to scale with Dynamic Type; omit it for a fixed size.
    public static func mono(_ size: CGFloat, weight: Font.Weight = .regular,
                            relativeTo textStyle: Font.TextStyle? = nil) -> Font {
        let base: Font
        if isAvailable(monoFamily) {
            if let textStyle {
                base = Font.custom(monoFamily, size: size, relativeTo: textStyle).weight(weight)
            } else {
                base = Font.custom(monoFamily, size: size).weight(weight)
            }
        } else {
            base = .system(size: size, weight: weight, design: .monospaced)
        }
        return base.monospacedDigit()
    }
```

- [ ] **Step 2: Fix the `ui(_:)` doc-comment lie**

In `…/Tokens/LumaFont.swift`, replace `ui` (lines 56–59). The current comment claims "full Dynamic Type + localization" but the implementation is a fixed `.system(size:)` — correct it:

```swift
    /// System UI face at a *fixed* point size. For Dynamic-Type scaling, use the
    /// `.lumaUIFont(_:)` view modifier instead — a system font cannot carry
    /// `relativeTo:`, so scaling must happen at the view via `@ScaledMetric`.
    public static func ui(_ size: CGFloat, weight: Font.Weight = .regular) -> Font {
        .system(size: size, weight: weight, design: .default)
    }
```

- [ ] **Step 3: Mark the instrument-readout opt-out + scale the chrome statics**

In `…/Tokens/LumaFont.swift`, replace the `Font` convenience block (lines 74–87):

```swift
public extension Font {
    /// The hero note name — Chakra Petch 600 @ 168. Deliberately **fixed**: the
    /// full-bleed instrument readout opts out of Dynamic Type (layout stability;
    /// already display-huge). See docs/rules/accessibility.md (Dynamic Type).
    static var lumaNote: Font { LumaFont.display(LumaFont.Size.note) }
    /// Card / section titles — Chakra Petch 600 @ 24 (scales).
    static var lumaTitle: Font { LumaFont.display(LumaFont.Size.xl2, relativeTo: .title) }
    /// The wordmark / small display labels @ 13 (scales).
    static var lumaWordmark: Font { LumaFont.display(LumaFont.Size.label, relativeTo: .caption) }
    /// Big signed cents readout — JetBrains Mono 500 @ 30. Deliberately **fixed**:
    /// part of the full-bleed instrument readout (opts out, see `lumaNote`).
    static var lumaCents: Font { LumaFont.mono(30, weight: .medium) }
    /// State-line hint — system 500 @ 15. NOTE: scaling for this size lives in
    /// `.lumaUIFont`; `StateLine` applies it directly (this static is fixed).
    static var lumaStateHint: Font { LumaFont.ui(LumaFont.Size.body, weight: .medium) }
    /// Freq line / chip mono @ 11 (scales).
    static var lumaMicroMono: Font { LumaFont.mono(LumaFont.Size.micro, relativeTo: .caption2) }
}
```

- [ ] **Step 4: Create the `@ScaledMetric` chrome-font modifier**

Create `Packages/LumaDesignSystem/Sources/LumaDesignSystem/Modifiers/ScaledUIFont.swift`:

```swift
import SwiftUI

/// A system (SF) font at a fixed point size that scales with Dynamic Type,
/// anchored to a text style. Use for chrome / settings / informational text:
/// `LumaFont.ui(_:)` returns a *fixed* `Font` (a system font cannot carry
/// `relativeTo:`), so scaling must happen at the view via `@ScaledMetric`.
public struct ScaledUIFont: ViewModifier {
    @ScaledMetric private var size: CGFloat
    private let weight: Font.Weight

    public init(size: CGFloat, weight: Font.Weight, relativeTo textStyle: Font.TextStyle) {
        self._size = ScaledMetric(wrappedValue: size, relativeTo: textStyle)
        self.weight = weight
    }

    public func body(content: Content) -> some View {
        content.font(.system(size: size, weight: weight))
    }
}

public extension View {
    /// Apply a Dynamic-Type-scaling system font (chrome / informational text).
    func lumaUIFont(_ size: CGFloat,
                    weight: Font.Weight = .regular,
                    relativeTo textStyle: Font.TextStyle = .body) -> some View {
        modifier(ScaledUIFont(size: size, weight: weight, relativeTo: textStyle))
    }
}
```

- [ ] **Step 5: Migrate the `LumaFont.ui(...)` chrome consumers to `.lumaUIFont(...)`**

Transformation rule: replace `.font(LumaFont.ui(<size>, weight: <w>))` with `.lumaUIFont(<size>, weight: <w>)` (drop the `.font(`). For `.font(.lumaStateHint)` use `.lumaUIFont(LumaFont.Size.body, weight: .medium)`.

Example — `App/SettingsView.swift:92` and `:100`:

```swift
// before:  .font(LumaFont.ui(LumaFont.Size.label))
// after:
                        .lumaUIFont(LumaFont.Size.label)
```

Example — `Packages/.../Components/StateLine.swift:26` (the hint):

```swift
// before:  Text(state.hint).font(.lumaStateHint).foregroundStyle(Color.lumaDim)
// after:
            Text(state.hint)
                .lumaUIFont(LumaFont.Size.body, weight: .medium)
                .foregroundStyle(Color.lumaDim)
```

Apply across every `LumaFont.ui` / `.lumaStateHint` chrome site:
- `App/SettingsView.swift:92, :100`
- `App/Views/Monetization/AccountSheet.swift` (each `LumaFont.ui(...)` site)
- `App/Views/Monetization/GearStoreScreen.swift` (each `LumaFont.ui(...)` site)
- `App/Views/Monetization/SaveCardSheet.swift:38, :87`
- `Packages/.../Components/StateLine.swift:26` (the `.lumaStateHint` hint)

The `display`/`mono` chrome sites scale automatically via the updated statics (`lumaWordmark`, `lumaMicroMono`, `lumaTitle`) — no per-site edit needed where those statics are used (`Brand`, `A4Control`, `EdgeButton`, `TargetChip`, `FreqLine`, `MenuBarTuner`). Where a chrome view calls `LumaFont.display(...)` / `LumaFont.mono(...)` **directly** with a literal size (e.g. `AccountSheet`/`GearStoreScreen` titles), add `relativeTo:` (e.g. `LumaFont.display(20, relativeTo: .title3)`). Do **not** add `relativeTo:` to `NoteReadout` (the 168/accidental) or `CentsReadout` (the big 30) — those are the opt-out.

- [ ] **Step 6: Add a largest-accessibility-size preview to the gallery**

In `Packages/LumaDesignSystem/Sources/LumaDesignSystem/Gallery/DesignSystemGallery.swift`, inside its `#if DEBUG` previews, add one that forces the largest accessibility size so chrome growth is visible:

```swift
#Preview("Gallery — accessibility XXXL") {
    DesignSystemGallery()
        .environment(\.dynamicTypeSize, .accessibility5)
        .preferredColorScheme(.dark)
}
```

*(If `DesignSystemGallery` is not the right preview host, add the equivalent `.environment(\.dynamicTypeSize, .accessibility5)` preview to `StateLine.swift` and `SettingsView`'s preview instead — the requirement is a forced-largest-size preview that shows chrome scaling and the instrument numerals holding.)*

- [ ] **Step 7: Build the DS package**

Run: `swift test --package-path Packages/LumaDesignSystem`
Expected: PASS (no new unit test here — C-2's verification is previews + build + review; existing tests must stay green).

- [ ] **Step 8: Build the app on macOS and iOS**

Run (both):
```
xcodebuild build -project LUMA.xcodeproj -scheme LUMA -destination 'platform=macOS' CODE_SIGNING_ALLOWED=NO
xcodebuild build -project LUMA.xcodeproj -scheme LUMA -destination 'generic/platform=iOS Simulator' CODE_SIGNING_ALLOWED=NO
```
Expected: `** BUILD SUCCEEDED **` on both. (SourceKit live-index diagnostics like "No such module" are false positives when the module graph isn't built — trust `xcodebuild`.)

- [ ] **Step 9: Commit**

```bash
git add Packages/LumaDesignSystem/Sources/LumaDesignSystem/Tokens/LumaFont.swift \
        Packages/LumaDesignSystem/Sources/LumaDesignSystem/Modifiers/ScaledUIFont.swift \
        Packages/LumaDesignSystem/Sources/LumaDesignSystem/Components/StateLine.swift \
        Packages/LumaDesignSystem/Sources/LumaDesignSystem/Gallery/DesignSystemGallery.swift \
        App/SettingsView.swift App/Views/Monetization
git commit -m "feat(a11y): scale chrome/settings text with Dynamic Type; instrument readout opts out (C-2)"
```

---

## Task 3: C-3 — WCAG AA contrast audit + color independence

**Files:**
- Create: `Packages/LumaDesignSystem/Tests/LumaDesignSystemTests/ContrastAuditTests.swift`
- Create: `docs/solutions/accessibility/state-color-contrast-audit-2026-06-19.md`
- Modify: `Packages/LumaDesignSystem/Sources/LumaDesignSystem/Components/StringRow.swift`
- Create: `Packages/LumaDesignSystem/Tests/LumaDesignSystemTests/StringRowA11yTests.swift`

**Interfaces:**
- Consumes: the module's `RGB(hex:)` (from `StrobePalette.swift`, exposed via `@testable import`).
- Produces: `StringCell.a11yLabel(idx:note:octave:active:locked:) -> String` — pure, so the VoiceOver label is testable.

> **Token resolution note for the implementer:** the asset-catalog hexes the audit asserts come from the `*.colorset/Contents.json` files (universal = light, `appearance: dark` = dark). Read the actual values from
> `Packages/LumaDesignSystem/Sources/LumaDesignSystem/Resources/Colors.xcassets/{bg,flat,sharp,inTune}.colorset/Contents.json`
> before writing the assertions; the literals below (`flat`/`sharp` dark/light, `bg`) are from those files at plan time — re-confirm them, since the test pins the design tokens.

- [ ] **Step 1: Write the failing contrast test**

Create `Packages/LumaDesignSystem/Tests/LumaDesignSystemTests/ContrastAuditTests.swift`. The WCAG relative-luminance + ratio helpers live in the **test target** (not shipping code — they exist only to enforce the design tokens):

```swift
import Testing
@testable import LumaDesignSystem

/// WCAG 2.x relative luminance + contrast ratio (sRGB). Test-only — enforces that
/// the design tokens meet AA so a future hex edit can't silently regress contrast.
private func relativeLuminance(_ c: RGB) -> Double {
    func lin(_ v: Double) -> Double { v <= 0.03928 ? v / 12.92 : pow((v + 0.055) / 1.055, 2.4) }
    return 0.2126 * lin(c.r) + 0.7152 * lin(c.g) + 0.0722 * lin(c.b)
}
private func contrastRatio(_ a: RGB, _ b: RGB) -> Double {
    let la = relativeLuminance(a), lb = relativeLuminance(b)
    let (hi, lo) = (max(la, lb), min(la, lb))
    return (hi + 0.05) / (lo + 0.05)
}

@Suite("WCAG AA contrast — state colors")
struct ContrastAuditTests {
    // Sanity: the formula reproduces the canonical black/white extreme (21:1).
    @Test("luminance formula is correct at the extremes")
    func formulaSanity() {
        #expect(abs(contrastRatio(RGB(0, 0, 0), RGB(1, 1, 1)) - 21.0) < 0.01)
        #expect(abs(contrastRatio(RGB(1, 1, 1), RGB(1, 1, 1)) - 1.0) < 0.01)
    }

    // RE-CONFIRM these hexes from the .colorset JSONs before relying on them.
    // bg:    light #E7EAF1 (universal), dark #0A0B10
    // flat:  light #2E6BFF,            dark #4D8BFF
    // sharp: light #D9760F,            dark #FFA53C
    // inTune:light #07A07C,            dark #28F0C0   (verify from inTune.colorset)
    let bgDark = RGB(hex: 0x0A0B10),  bgLight = RGB(hex: 0xE7EAF1)

    @Test("state colors meet AA text contrast (4.5:1) in both appearances")
    func stateTextContrast() {
        let dark: [(String, RGB)] = [
            ("flat",   RGB(hex: 0x4D8BFF)),
            ("sharp",  RGB(hex: 0xFFA53C)),
            ("inTune", RGB(hex: 0x28F0C0)),
        ]
        let light: [(String, RGB)] = [
            ("flat",   RGB(hex: 0x2E6BFF)),
            ("sharp",  RGB(hex: 0xD9760F)),
            ("inTune", RGB(hex: 0x07A07C)),
        ]
        for (name, c) in dark {
            #expect(contrastRatio(c, bgDark) >= 4.5, "\(name) (dark) below AA text")
        }
        for (name, c) in light {
            #expect(contrastRatio(c, bgLight) >= 4.5, "\(name) (light) below AA text")
        }
    }
}
```

- [ ] **Step 2: Run the contrast test to see real ratios**

Run: `swift test --package-path Packages/LumaDesignSystem --filter "WCAG AA contrast"`
Expected: the `formulaSanity` test PASSES. `stateTextContrast` either passes (tokens already AA — likely for several) or **fails for specific tokens**, printing which color/appearance is below 4.5:1. **Record every computed ratio** (pass and fail) — it feeds Step 3 and Step 4.

- [ ] **Step 3: Write the documented audit**

Create `docs/solutions/accessibility/state-color-contrast-audit-2026-06-19.md` with a table of every state color × appearance, its measured ratio vs. the resolved background, and pass/fail vs. AA (4.5:1 text / 3:1 graphics). Include a section for the strobe palette (`StrobePalette.swift` aurora slots) audited at 3:1 graphics. State the conclusion explicitly. Template:

```markdown
# State-color contrast audit — WCAG AA (2026-06-19)

Source rule: docs/rules/accessibility.md (Contrast). Method: WCAG 2.x sRGB
relative-luminance ratio (see ContrastAuditTests). Backgrounds: dark #0A0B10,
light #E7EAF1.

| Token | Appearance | Hex | vs. bg | Ratio | AA text (4.5) | AA graphic (3.0) |
|-------|-----------|-----|--------|-------|---------------|------------------|
| flat | dark | #4D8BFF | #0A0B10 | <fill> | <pass/fail> | <pass/fail> |
| …    | …    | …       | …       | …      | …           | …               |

## Strobe palette (graphics, 3:1) — StrobePalette.swift aurora
| Slot | Appearance | Hex | vs. bg | Ratio | AA graphic (3.0) |
| …    | …    | …       | …       | …      | …               |

## Conclusion
<e.g. "All asset-catalog state colors meet AA text in both appearances; no token
changed." OR "flat (light) measured 3.9:1 — adjusted lightness #2E6BFF → #2A5FE0
(hue preserved), now 4.6:1.">
```

- [ ] **Step 4: Resolve any failures (hue-preserving only)**

If any asset-catalog token fails AA: change **lightness only** in its `*.colorset/Contents.json` (keep hue/saturation), re-run Step 2 until it passes, and record the before/after + new ratio in the audit doc. **If a fix would require shifting the brand hue, do NOT change it** — report it in the implementer's notes as a design decision for the user, and leave the test asserting the current (failing) value `@Test(.disabled("surfaced to design: <token> needs a hue change"))` so CI stays green while the gap is visible. Same rule for the strobe palette: audit + document only; no silent retune.

- [ ] **Step 5: Write the failing StringRow a11y-label test**

Create `Packages/LumaDesignSystem/Tests/LumaDesignSystemTests/StringRowA11yTests.swift`:

```swift
import Testing
@testable import LumaDesignSystem

@Suite("StringRow VoiceOver label conveys state")
struct StringRowA11yTests {
    @Test("locked (in-tune) state is announced, not color-only")
    func lockedAnnounced() {
        let label = StringCell.a11yLabel(idx: 6, note: "E", octave: 2, active: true, locked: true)
        #expect(label.contains("E2"))
        #expect(label.localizedCaseInsensitiveContains("in tune"))
    }

    @Test("plain string announces only its identity")
    func plain() {
        let label = StringCell.a11yLabel(idx: 6, note: "E", octave: 2, active: false, locked: false)
        #expect(label.contains("String 6"))
        #expect(!label.localizedCaseInsensitiveContains("in tune"))
    }
}
```

- [ ] **Step 6: Run it to verify it fails**

Run: `swift test --package-path Packages/LumaDesignSystem --filter "StringRow VoiceOver"`
Expected: FAIL to compile — `Type 'StringCell' has no member 'a11yLabel'`.

- [ ] **Step 7: Extract the pure label + honor `differentiateWithoutColor`**

In `…/Components/StringRow.swift`, add the pure label helper to `StringCell` and use it; add a non-color cue under `differentiateWithoutColor`. Add the env read near the other `@Environment` lines (after line 49):

```swift
    @Environment(\.accessibilityDifferentiateWithoutColor) private var diffWithoutColor
```

Add the static helper inside `StringCell` (e.g. after the computed colors):

```swift
    /// VoiceOver label — announces identity AND lock state so the in-tune state
    /// is never color-only. Pure for testability.
    static func a11yLabel(idx: Int, note: String, octave: Int, active: Bool, locked: Bool) -> String {
        var label = "String \(idx), \(note)\(octave)"
        if locked { label += ", in tune" }
        else if active { label += ", selected" }
        return label
    }
```

Replace the `.accessibilityLabel(...)` line (currently line 93) with:

```swift
        .accessibilityLabel(StringCell.a11yLabel(idx: string.idx, note: string.note, octave: string.octave, active: active, locked: locked))
```

Add a non-color lock cue. Insert a checkmark overlay shown only when locked AND the user has asked to differentiate without color — add this `.overlay` after the existing `.overlay(alignment: .topLeading) { … }` block (it nests the locked glyph in the opposite corner):

```swift
        .overlay(alignment: .bottomTrailing) {
            if locked && diffWithoutColor {
                Image(systemName: "checkmark.circle.fill")
                    .font(.system(size: 11, weight: .bold))
                    .foregroundStyle(tuneColor)
                    .padding(.bottom, 4)
                    .padding(.trailing, 6)
            }
        }
```

- [ ] **Step 8: Run the StringRow test to verify it passes**

Run: `swift test --package-path Packages/LumaDesignSystem --filter "StringRow VoiceOver"`
Expected: PASS (2 tests).

- [ ] **Step 9: Add a `differentiateWithoutColor` preview**

In `…/Components/StringRow.swift`, inside `#if DEBUG`, add:

```swift
#Preview("String row — differentiate without color") {
    StringRow(tuning: Tunings.guitar, activeIdx: .constant(5), lockedIdx: 5)
        .padding(24)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color.lumaBg)
        .environment(\.accessibilityDifferentiateWithoutColor, true)
        .preferredColorScheme(.dark)
}
```

- [ ] **Step 10: Run the full DS suite + commit**

Run: `swift test --package-path Packages/LumaDesignSystem`
Expected: PASS — all existing + `ContrastAuditTests` + `StringRowA11yTests`.

```bash
git add Packages/LumaDesignSystem/Tests/LumaDesignSystemTests/ContrastAuditTests.swift \
        Packages/LumaDesignSystem/Tests/LumaDesignSystemTests/StringRowA11yTests.swift \
        Packages/LumaDesignSystem/Sources/LumaDesignSystem/Components/StringRow.swift \
        Packages/LumaDesignSystem/Sources/LumaDesignSystem/Resources/Colors.xcassets \
        docs/solutions/accessibility/state-color-contrast-audit-2026-06-19.md
git commit -m "feat(a11y): WCAG AA contrast audit + honor differentiateWithoutColor in StringRow (C-3)"
```

---

## Task 4a: C-4 — Photosensitivity analysis (WCAG 2.3.1)

**Model:** most-capable, **strobe-specialist review**. This task writes **no shipping code** — it produces the determination that gates Task 4b.

**Files:**
- Create: `docs/solutions/accessibility/strobe-photosensitivity-2026-06-19.md`
- Modify: `docs/rules/strobe.md` (one-line note recording the check)

**Background the analyst must use (verified):**
- Production renders with `phaseScroll: true` (`App/LiveTunerScreen.swift:47`; `StageView` too). The off-pitch scroll/rotation velocity is derived from the engine's live `StrobeInput.phase` advance — **one phase wrap = one cycle**, so the cycle (flash) frequency equals the acoustic **beat frequency** between played and target pitch. It is **not** bounded by the cents-derived `StrobeMath.scrollSpeed`/`ringSpeed` (those drive the simulator/preview path only).
- The field is **full-screen** (`StrobeField` is the bottom ZStack layer, no frame, behind readouts; `StageView` is `.ignoresSafeArea()`), high luminance delta — bright additive ribbons/marks (`StrobePalette` aurora dark: tune `#28F0C0`, flat `#4D8BFF`, sharp `#FFA53C`) over near-black `#0A0B10`. Aurora uses ~13 ribbons; Radial 36 marks.
- Existing mitigation: `StrobeField` swaps to `ReducedGauge` under **Reduce Motion only** — which does **not** discharge WCAG 2.3.1 (Level A, applies to the default experience).

- [ ] **Step 1: Quantify the worst-case flash characteristics**

Compute, showing the work, for the default (no accessibility traits) off-pitch strobe:
- **Flash rate range:** the beat-frequency range across the tuner's tracked detune window (the engine's strobe phase rate) for representative pitches (lowest bass string ~31–41 Hz fundamental up through high guitar), including how many bright ribbons/marks pass a fixed point per second (per-pixel flicker = ribbon-count × wraps/sec for Aurora; mark sweep for Radial).
- **Concurrent bright-area fraction:** what fraction of the screen undergoes a synchronized luminance reversal at once (the traveling-wave argument — out-of-phase regions reduce concurrent area; quantify it for ~13 ribbons / 36 marks, not just assert it).
- **Luminance delta:** relative-luminance swing between the bright ribbon peak and the near-black trough (reuse the WCAG luminance formula from `ContrastAuditTests`).

- [ ] **Step 2: Apply the WCAG 2.3.1 threshold**

State the determination against "no more than three general/red flashes within any one-second period, OR the flash is below the threshold" — general flash threshold concerns a large area (> ~25% of central field / > 0.006 steradians) flashing in unison. Conclude one of:
- **SAFE** — the traveling-wave structure keeps the *concurrent* large-area flash below threshold across the whole pitch range, OR
- **HAZARD** — at some realistic pitch/detune the default strobe can present >3 large-area reversals/sec.

- [ ] **Step 3: Write the analysis doc**

Create `docs/solutions/accessibility/strobe-photosensitivity-2026-06-19.md` capturing Steps 1–2: the numbers, the method, the threshold, and the conclusion. If HAZARD, specify the recommended mitigation parameter for Task 4b (the single value 4b needs — e.g. "cap effective whole-field flash rate at ≤ 3 Hz" or "cap luminance delta to ≤ X when beat rate > 3 Hz").

- [ ] **Step 4: Record the one-line note in the rule**

In `docs/rules/strobe.md`, add a one-line note under the photosensitivity/accessibility area recording that the off-pitch animation was checked against WCAG 2.3.1 on 2026-06-19, with the verdict and a link to the analysis doc. (This is the deliverable `accessibility.md` line 12 mandates — it is the **only** edit to a `docs/rules/` file allowed by this sub-project, and it records a check, not a behaviour change.)

- [ ] **Step 5: Commit**

```bash
git add docs/solutions/accessibility/strobe-photosensitivity-2026-06-19.md docs/rules/strobe.md
git commit -m "docs(a11y): WCAG 2.3.1 photosensitivity analysis of the off-pitch strobe (C-4a)"
```

- [ ] **Step 6: Controller gate**

The controller reads the analysis. **SAFE → C-4 is complete; skip Task 4b.** **HAZARD → dispatch Task 4b** with the mitigation parameter from Step 3. Record the branch taken in the SDD ledger.

---

## Task 4b (CONDITIONAL — only if Task 4a concludes HAZARD): flash-rate / luminance mitigation

**Model:** most-capable, **strobe-specialist review**. Touches the Metal shaders — the highest-risk change in the sub-project.

**Files:**
- Modify: `Packages/LumaDesignSystem/Sources/LumaDesignSystem/Strobe/StrobeMath.swift` (the pure clamp)
- Modify: the phase-driven renderers that apply velocity/luminance — `Strobe/AuroraStrobe.swift`, `Strobe/RadialStrobe.swift`, `Strobe/MetalStrobe.swift`, `Strobe/RadialMetalStrobe.swift` (apply the clamp where `scrollVel`/`rotVel`/brightness is computed)
- Create: `Packages/LumaDesignSystem/Tests/LumaDesignSystemTests/PhotosensitivityClampTests.swift`

**Interfaces:**
- Produces: `StrobeMath.clampedFlashRate(_ rate: Double) -> Double` (or `clampedLuminanceDelta(_:beatRate:)` — whichever 4a prescribes) — pure, capped at the threshold constant from 4a.

- [ ] **Step 1: Write the failing clamp test**

Create `…/PhotosensitivityClampTests.swift` (adjust the function name/semantics to 4a's prescription; this is the flash-rate-cap variant):

```swift
import Testing
@testable import LumaDesignSystem

@Suite("WCAG 2.3.1 flash-rate clamp")
struct PhotosensitivityClampTests {
    @Test("passes rates at or below the cap unchanged")
    func belowCap() {
        #expect(StrobeMath.clampedFlashRate(0) == 0)
        #expect(StrobeMath.clampedFlashRate(StrobeMath.maxFlashRateHz) == StrobeMath.maxFlashRateHz)
    }
    @Test("caps rates above the threshold")
    func aboveCap() {
        #expect(StrobeMath.clampedFlashRate(12) == StrobeMath.maxFlashRateHz)
        #expect(StrobeMath.clampedFlashRate(-12) == -StrobeMath.maxFlashRateHz) // sign preserved
    }
}
```

- [ ] **Step 2: Run it to verify it fails**

Run: `swift test --package-path Packages/LumaDesignSystem --filter "flash-rate clamp"`
Expected: FAIL to compile — `clampedFlashRate`/`maxFlashRateHz` undefined.

- [ ] **Step 3: Add the pure clamp to `StrobeMath`**

In `…/Strobe/StrobeMath.swift`, add (use the threshold value from Task 4a's doc):

```swift
    // MARK: WCAG 2.3.1 photosensitivity guard

    /// Maximum whole-field flash rate (Hz) the default strobe may present, per the
    /// 2026-06-19 photosensitivity analysis (docs/solutions/accessibility/
    /// strobe-photosensitivity-2026-06-19.md). Below WCAG 2.3.1's 3-flash limit.
    static let maxFlashRateHz: Double = 3.0   // ← set to 4a's prescribed value

    /// Clamp an effective flash rate (signed) to ±`maxFlashRateHz`, preserving sign.
    static func clampedFlashRate(_ rate: Double) -> Double {
        max(-maxFlashRateHz, min(maxFlashRateHz, rate))
    }
```

- [ ] **Step 4: Run the clamp test to verify it passes**

Run: `swift test --package-path Packages/LumaDesignSystem --filter "flash-rate clamp"`
Expected: PASS.

- [ ] **Step 5: Apply the clamp in the phase-driven renderers**

In each of `AuroraStrobe.swift`, `RadialStrobe.swift`, `MetalStrobe.swift`, `RadialMetalStrobe.swift`, route the phase-derived velocity (`scrollVel` / `rotVel`, converted to whole-field cycles/sec) through `StrobeMath.clampedFlashRate(...)` before it advances `scroll`/`angle`, so the default off-pitch flash rate cannot exceed the cap. (Exact insertion points per 4a's prescription; keep the on-pitch/lock behaviour identical — the clamp only bites at high beat rates.) The strobe-specialist reviewer verifies the Metal shader edits preserve the triple-buffer contract and don't regress 120 fps.

- [ ] **Step 6: Build + test everything**

Run:
```
swift test --package-path Packages/LumaDesignSystem
xcodebuild build -project LUMA.xcodeproj -scheme LUMA -destination 'platform=macOS' CODE_SIGNING_ALLOWED=NO
xcodebuild build -project LUMA.xcodeproj -scheme LUMA -destination 'generic/platform=iOS Simulator' CODE_SIGNING_ALLOWED=NO
```
Expected: tests PASS; both builds `** BUILD SUCCEEDED **`.

- [ ] **Step 7: Update the analysis doc + commit**

Note in `docs/solutions/accessibility/strobe-photosensitivity-2026-06-19.md` that the mitigation was applied (cap value, where). Commit:

```bash
git add Packages/LumaDesignSystem/Sources/LumaDesignSystem/Strobe \
        Packages/LumaDesignSystem/Tests/LumaDesignSystemTests/PhotosensitivityClampTests.swift \
        docs/solutions/accessibility/strobe-photosensitivity-2026-06-19.md
git commit -m "feat(a11y): clamp off-pitch strobe flash rate below WCAG 2.3.1 threshold (C-4b)"
```

---

## Task 5: Wrap-up — archive the four todos

**Files:**
- `git mv` `docs/todos/{P2-reduce-transparency,P2-dynamic-type-chrome,P2-contrast-color-independence,P3-strobe-photosensitivity-check}.md` → `docs/todos/archive/`

- [ ] **Step 1: Append a resolution note to each todo**

To each of the four todo files, append a `## Resolution (2026-06-19, sub-project 3)` section naming the implementing commit(s) and the deviation/outcome where relevant — in particular:
- `P2-reduce-transparency`: note `ScreenBackground` was included (the shipped wash), not only `FieldWash`.
- `P2-contrast-color-independence`: state the audit outcome (tokens passed, or which were lightness-adjusted, or which were surfaced to the user); note the StringRow VoiceOver-label fix was folded in here (not a separate B-5).
- `P3-strobe-photosensitivity-check`: state the verdict (SAFE → documented, no code; or HAZARD → clamp applied), with the measured numbers — so a "no code changed" outcome reads as a verified decision, not a skipped task.

- [ ] **Step 2: Archive (preserve history)**

```bash
cd /Users/williamtower/projects/guitar_tuner
git mv docs/todos/P2-reduce-transparency.md docs/todos/archive/
git mv docs/todos/P2-dynamic-type-chrome.md docs/todos/archive/
git mv docs/todos/P2-contrast-color-independence.md docs/todos/archive/
git mv docs/todos/P3-strobe-photosensitivity-check.md docs/todos/archive/
```

- [ ] **Step 3: Final verification (whole sub-project)**

Run all four gates green:
```
swift test --package-path Packages/LumaDesignSystem
swift test --package-path Packages/TunerEngine
xcodebuild build -project LUMA.xcodeproj -scheme LUMA -destination 'platform=macOS' CODE_SIGNING_ALLOWED=NO
xcodebuild build -project LUMA.xcodeproj -scheme LUMA -destination 'generic/platform=iOS Simulator' CODE_SIGNING_ALLOWED=NO
./scripts/ci-invariants.sh
```
Expected: tests PASS; both builds succeed; invariant scan **0 HARD / 0 REVIEW**.

- [ ] **Step 4: Commit**

```bash
git add docs/todos
git commit -m "chore(todos): archive C-1…C-4 accessibility todos (sub-project 3)"
```

---

## After all tasks

Per subagent-driven-development: dispatch the final whole-branch code review (most-capable model; include a **strobe-specialist** pass if Task 4b ran), fix Critical/Important findings, then use superpowers:finishing-a-development-branch. The PR body must state the C-4 outcome (SAFE-documented vs. HAZARD-mitigated, with numbers) and the C-3 audit outcome, per the spec's transparency-at-the-seam rule.
