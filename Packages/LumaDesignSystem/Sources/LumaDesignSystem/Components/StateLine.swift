import SwiftUI

/// The state line: a small outlined tag (STANDBY / FLAT / SHARP / IN TUNE) plus
/// a plain-language hint. Colour follows the state; idle is `faint`. Mirrors
/// `.state-line` / `StateLine` in the export.
public struct StateLine: View {
    let state: TunerVisualState

    public init(state: TunerVisualState) {
        self.state = state
    }

    public var body: some View {
        // The tag is a small (10 pt) label — normal text under WCAG, so it uses the
        // text-safe state colorset token (AA 4.5:1 on the light bg) for ALL states,
        // including the in-tune "sacred" state. Previously the in-tune tag inherited
        // the palette-resolved tune glow, which sits below 4.5:1 in light mode; the
        // vivid palette tune still drives the hero NoteReadout bloom and the strobe
        // ribbon, where it reads as a graphic (3:1). The tag is now palette-agnostic
        // like FLAT/SHARP. See ContrastAuditTests.stateTextContrast_light.
        let tagColor = state.glow
        HStack(spacing: 9) {
            Text(state.tag)
                .font(LumaFont.mono(10, relativeTo: .caption2))
                .lumaTracking(Tracking.tag, size: 10)
                .textCase(.uppercase)
                .padding(.horizontal, 8)
                .padding(.vertical, 3)
                .overlay(Capsule().stroke(tagColor, lineWidth: 1))
            Text(state.hint)
                .lumaUIFont(LumaFont.Size.body, weight: .medium)
                .foregroundStyle(Color.lumaDim)
        }
        .foregroundStyle(tagColor)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(state.tag), \(state.hint)")
    }
}

#if DEBUG
private struct StateLineGallery: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            StateLine(state: .flat)
            StateLine(state: .sharp)
            StateLine(state: .tune)
            StateLine(state: .idle)
        }
        .padding(40)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color.lumaBg)
    }
}

#Preview("State line — dark") { StateLineGallery().preferredColorScheme(.dark) }
#Preview("State line — light") { StateLineGallery().preferredColorScheme(.light) }
#endif
