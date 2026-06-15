import SwiftUI

/// **Stage Mode** (EXPERIENCE §8) — one tap → a maximum-contrast, full-screen
/// strobe + note for glancing from a distance under stage lights. Pure black
/// canvas (not the usual cool near-black) for the highest contrast, the live
/// hero strobe full-bleed, the note / cents / state stack centred, and *no*
/// chrome or dock competing for the screen.
///
/// Logic-free: it renders whatever the live model feeds it (the same `StrobeInput`
/// + readout values as `LiveTunerScreen`). The app owns the toggle and the
/// keep-awake side effect; this view just presents and reports `onExit`. Reduce
/// Motion is honoured automatically — `StrobeField` swaps in the still gauge.
public struct StageView: View {
    var input: StrobeInput
    var note: String
    var octave: Int
    /// `nil` when there's no confident pitch (idle / silence).
    var cents: Double?
    var style: StrobeStyle
    var phaseScroll: Bool
    var onExit: () -> Void

    public init(input: StrobeInput, note: String, octave: Int, cents: Double?, style: StrobeStyle = .aurora, phaseScroll: Bool = false, onExit: @escaping () -> Void) {
        self.input = input
        self.note = note
        self.octave = octave
        self.cents = cents
        self.style = style
        self.phaseScroll = phaseScroll
        self.onExit = onExit
    }

    private var state: TunerVisualState { TunerVisualState.from(cents: cents, locked: input.locked) }

    public var body: some View {
        ZStack {
            // Maximum contrast: pure black under the luminous strobe.
            Color.black.ignoresSafeArea()
            StrobeField(input: input, style: style, phaseScroll: phaseScroll)
                .ignoresSafeArea()
                .allowsHitTesting(false)

            // Hero readouts — the one thing you read from across the room.
            VStack(spacing: Space.s5) {
                NoteReadout(note: note, octave: octave, locked: state == .tune, dimmed: input.isIdle)
                if cents != nil {
                    CentsReadout(cents: cents ?? 0, state: state)
                    StateLine(state: state)
                        .padding(.top, Space.s3)
                } else {
                    StateLine(state: .idle)
                        .padding(.top, Space.s4)
                }
            }
            .allowsHitTesting(false)

            // Exit affordance — an accessible control plus a quiet hint; the whole
            // field is also tappable to leave (below).
            VStack {
                HStack {
                    Spacer()
                    EdgeIconButton(systemImage: "arrow.down.right.and.arrow.up.left",
                                   accessibilityLabel: "Exit Stage Mode",
                                   action: onExit)
                }
                Spacer()
                Text("tap to exit")
                    .font(.lumaMicroMono)
                    .foregroundStyle(Color.lumaFaint)
                    .accessibilityHidden(true)
            }
            .padding(Space.s6)
        }
        .lumaGlow(state)
        .foregroundStyle(Color.lumaInk)
        .contentShape(Rectangle())
        .onTapGesture(perform: onExit)
        .accessibilityAddTraits(.isModal)
    }
}

#if DEBUG
#Preview("Stage — flat (dark)") {
    StageView(input: StrobeInput(cents: -18), note: "A", octave: 2, cents: -18, style: .aurora) {}
        .preferredColorScheme(.dark)
}

#Preview("Stage — locked · radial") {
    StageView(input: StrobeInput(cents: 0, locked: true), note: "E", octave: 4, cents: 0, style: .radial) {}
        .preferredColorScheme(.dark)
}

#endif
