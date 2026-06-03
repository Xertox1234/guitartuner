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
        HStack(spacing: 9) {
            Text(state.tag)
                .font(LumaFont.mono(10))
                .lumaTracking(Tracking.tag, size: 10)
                .textCase(.uppercase)
                .padding(.horizontal, 8)
                .padding(.vertical, 3)
                .overlay(Capsule().stroke(state.glow, lineWidth: 1))
            Text(state.hint)
                .font(.lumaStateHint)
                .foregroundStyle(Color.lumaDim)
        }
        .foregroundStyle(state.glow)
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
