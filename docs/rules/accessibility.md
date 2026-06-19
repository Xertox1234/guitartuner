# Accessibility rules

Cross-cutting domain — co-injected when editing any user-facing file (App views,
design-system components, strobe renderers, gallery).

- **Reduce Motion.** Honor `@Environment(\.accessibilityReduceMotion)`; substitute the `ReducedGauge` readout — do not merely slow the animation. (Operational detail lives in `strobe.md`.)
- **Reduce Transparency.** Honor `@Environment(\.accessibilityReduceTransparency)`; attenuate additive bloom (`.bloom()`) and `FieldWash` translucency when enabled.
- **Dynamic Type.** Chrome / settings / informational text scales with the user's content-size preference — use `.custom(_:size:relativeTo:)` or `@ScaledMetric`, never a fixed `.custom(_:size:)` for body text. The primary instrument readout (note name, strobe) may opt out of scaling, but the opt-out must be deliberate and commented.
- **VoiceOver.** Every interactive or stateful component carries an `accessibilityLabel`. Pitch-bearing views expose a live `accessibilityValue` ("in tune", signed cents). New components ship with labels — same bar as the `#Preview` requirement.
- **Color independence.** Never signal state by color alone; honor `@Environment(\.accessibilityDifferentiateWithoutColor)`. Preserve the existing redundancy: textual state line + strobe scroll direction + signed cents. Compact/menu-bar affordances need a non-color cue.
- **Contrast.** State colors and text meet WCAG AA (4.5:1 text / 3:1 graphics) in **both** appearances — validate light mode explicitly (dark-first must not leave light under-checked).
- **Photosensitivity.** The off-pitch strobe animation is verified against the WCAG 2.3.1 flash threshold (rate × luminance-delta × area); record the check in `strobe.md`.
- **Haptics.** The in-tune lock haptic is a non-visual confirmation channel — preserve it.
