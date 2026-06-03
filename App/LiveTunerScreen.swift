import SwiftUI
import LumaDesignSystem
import TunerEngine

/// The live Tuner screen — the real `TunerEngine` driving the Aurora strobe via
/// `LiveTunerModel`, with the full LUMA layout: top chrome, the hero strobe + note
/// stack, and the controls dock (Auto/String-lock toggle, string row, tone). A4
/// calibration and tuning presets live in the Settings sheet. Phase-driven scroll
/// (`phaseScroll: true`) uses the engine's live phase for true-strobe motion.
///
/// Live capture can't run in CI (no audio device) — it compiles here and runs
/// on-device; `LiveTunerModel` surfaces availability/permission issues as status.
struct LiveTunerScreen: View {
    @State private var model = LiveTunerModel()
    @State private var showSettings = false
    /// Persisted hero-strobe choice (Aurora default); shared with the Settings sheet
    /// via the same key. Reduce Motion still overrides to the still gauge.
    @AppStorage("strobeStyle") private var strobeStyle: StrobeStyle = .aurora

    private var state: TunerVisualState { TunerVisualState.from(cents: model.cents) }

    /// The string cell glows mint only when we're locked *onto that target*.
    private var lockedIdx: Int? {
        (model.mode == .lock && state == .tune) ? model.activeIdx : nil
    }

    var body: some View {
        ZStack {
            ScreenBackground()
            StrobeField(input: model.strobeInput, idle: model.idle, style: strobeStyle, phaseScroll: true)
            VStack(spacing: 0) {
                topChrome
                Spacer(minLength: Space.s4)
                readouts
                Spacer(minLength: Space.s4)
                dock
            }
        }
        .lumaGlow(state)
        .foregroundStyle(Color.lumaInk)
        .task { await model.start() }
        .onDisappear { model.stop() }
        .sheet(isPresented: $showSettings) { SettingsView(model: model) }
    }

    // MARK: Top chrome

    private var topChrome: some View {
        HStack {
            Brand()
            Spacer()
            InputSource(source: inputBinding)
            SettingsButton { showSettings = true }
        }
        .padding(.horizontal, Space.s6)
        .padding(.top, Space.s5)
    }

    // MARK: Readouts (reused Plan 02 components)

    private var readouts: some View {
        VStack(spacing: 0) {
            NoteReadout(note: model.note, octave: model.octave,
                        locked: state == .tune, dimmed: model.idle)
            CentsReadout(cents: model.cents ?? 0, state: state)
                .padding(.top, Space.s5)
            StateLine(state: state)
                .padding(.top, Space.s4)
            FreqLine(freq: model.frequency, algo: "MPM", rate: "48k")
                .padding(.top, Space.s3)
        }
        .allowsHitTesting(false)
    }

    // MARK: Dock

    private var dock: some View {
        VStack(spacing: Space.s4) {
            TargetChip(mode: modeBinding)

            StringRow(
                tuning: model.tuning,
                activeIdx: .constant(model.activeIdx),
                lockedIdx: lockedIdx,
                onPick: { model.selectString($0) }
            )

            HStack(spacing: Space.s3) {
                Button { Task { await model.toggle() } } label: {
                    Label(model.running ? "Stop" : "Start",
                          systemImage: model.running ? "stop.fill" : "mic.fill")
                }
                .buttonStyle(EdgeButtonStyle(active: model.running))

                Spacer()

                ToneToggle(on: $model.toneOn, label: toneLabel)
            }

            Text(model.status)
                .font(LumaFont.mono(10))
                .foregroundStyle(Color.lumaDim)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
                .frame(maxWidth: .infinity)
        }
        .padding(Space.s5)
        .background(Color.lumaSurface.opacity(0.55),
                    in: RoundedRectangle(cornerRadius: Radius.r4, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: Radius.r4, style: .continuous)
            .stroke(Color.lumaLine, lineWidth: 1))
        .padding(.horizontal, Space.s5)
        .padding(.bottom, Space.s5)
    }

    /// The tone toggle names the string it will sound, e.g. `Tone · A2`.
    private var toneLabel: String {
        if let s = model.activeString { return "Tone · \(s.note)\(s.octave)" }
        return "Tone"
    }

    // MARK: Bindings into the @Observable model

    private var modeBinding: Binding<TargetMode> {
        Binding(get: { model.mode }, set: { model.setMode($0) })
    }

    private var inputBinding: Binding<InputKind> {
        Binding(get: { model.inputKind }, set: { model.setInputKind($0) })
    }
}

#if DEBUG
#Preview("Live Tuner — dark") {
    LiveTunerScreen().preferredColorScheme(.dark)
}
#endif
