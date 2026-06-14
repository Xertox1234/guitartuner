import SwiftUI

/// The four visual states the readouts encode. Error is **never colour alone** —
/// each state carries colour **+** a sign/arrow **+** copy. Mirrors the
/// `data-state` values and `vstateGlow()` in `tuner-ui.jsx`.
public enum TunerVisualState: String, CaseIterable, Sendable {
    case idle   // STANDBY — no signal
    case flat   // below pitch — tune up
    case sharp  // above pitch — tune down
    case tune   // locked / in tune — the sacred state

    /// Glow hue for the field + bloom (`--glow`). Non-tune states return fixed
    /// design-token colours; for the tune state use `glow(palette:scheme:)` to
    /// get the palette-resolved hue.
    public var glow: Color {
        switch self {
        case .tune: .lumaInTune
        case .flat: .lumaFlat
        case .sharp: .lumaSharp
        case .idle: .lumaFaint
        }
    }

    /// Palette-resolved glow hue. Returns the palette's tune colour for `.tune`;
    /// for all other states falls back to the fixed design-token colour.
    public func glow(palette: LumaPalette, scheme: ColorScheme) -> Color {
        guard self == .tune else { return glow }
        return Color(StrobePalette.resolve(scheme, palette: palette).tune, opacity: 1)
    }

    /// Accent colour for the readouts (note/cents/state line).
    public var accent: Color { glow }

    /// Uppercase tag shown in the state-line pill.
    public var tag: String {
        switch self {
        case .idle: "STANDBY"
        case .flat: "FLAT"
        case .sharp: "SHARP"
        case .tune: "IN TUNE"
        }
    }

    /// Plain-language hint beside the tag.
    public var hint: String {
        switch self {
        case .idle: "pluck a string"
        case .flat: "tune up"
        case .sharp: "tune down"
        case .tune: "hold it"
        }
    }

    /// Derive the visual state from a signed cents value and the confidence-gated
    /// lock flag. `locked` must be `true` to reach `.tune` — cents proximity alone
    /// is not sufficient (avoids desync with the strobe bloom during note decay).
    /// `nil` cents means no signal → idle.
    public static func from(cents: Double?, locked: Bool = false) -> TunerVisualState {
        guard let cents else { return .idle }
        if locked { return .tune }
        return cents < 0 ? .flat : .sharp
    }
}
