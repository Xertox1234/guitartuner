#if os(macOS)
import SwiftUI
import LumaDesignSystem

/// The macOS **menu-bar micro-strobe** (EXPERIENCE §8): a compact live ring + note
/// hanging off the menu bar for quick checks while recording, without bringing the
/// main window forward. *Same DSP, same look* — it shares the one `LiveTunerModel`
/// (one engine, one mic) with `LiveTunerScreen` and honors the persisted
/// Aurora/Radial choice; Reduce Motion still swaps in the still gauge.
struct MenuBarTuner: View {
    @Bindable var model: LiveTunerModel
    /// Shared with the live screen + Settings via the same key.
    @AppStorage("strobeStyle") private var strobeStyle: StrobeStyle = .aurora
    /// Shared with the live screen + Settings via the same key.
    @AppStorage("strobePalette") private var palette: LumaPalette = .aurora

    private var state: TunerVisualState { TunerVisualState.from(cents: model.cents, locked: model.strobeInput.locked) }

    var body: some View {
        VStack(spacing: Space.s4) {
            StrobeField(input: model.strobeInput,
                        style: strobeStyle, phaseScroll: true)
                .lumaPalette(palette)
                .frame(width: 132, height: 132)
                .clipShape(Circle())
                .allowsHitTesting(false)

            NoteReadout(note: model.note, octave: model.octave,
                        locked: state == .tune, dimmed: model.idle)
            CentsReadout(cents: model.cents ?? 0, state: state)
            StateLine(state: state)

            Button { Task { await model.toggle() } } label: {
                Label(model.running ? "Stop" : "Listen",
                      systemImage: model.running ? "stop.fill" : "mic.fill")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(EdgeButtonStyle(active: model.running))

            Text("Quick check — the main window has the full tuner.")
                .font(.lumaMicroMono)
                .foregroundStyle(Color.lumaFaint)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(Space.s5)
        .frame(width: 240)
        .background(Color.lumaBg)
        .foregroundStyle(Color.lumaInk)
        .lumaGlow(state)
    }
}

/// The glyph shown *in* the menu bar. The tuning fork is LUMA's mark; the note
/// appears beside it once there's a live reading (`MenuBarStrobe.caption`), so the
/// bar is quiet at rest and glanceable while playing.
struct MenuBarLabel: View {
    var model: LiveTunerModel

    private var state: TunerVisualState { TunerVisualState.from(cents: model.cents, locked: model.strobeInput.locked) }

    var body: some View {
        let caption = MenuBarStrobe.caption(note: model.note, running: model.running, state: state)
        if caption.isEmpty {
            Image(systemName: "tuningfork")
        } else {
            Label(caption, systemImage: "tuningfork")
        }
    }
}
#endif
