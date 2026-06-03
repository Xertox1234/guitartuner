import SwiftUI
import LumaDesignSystem
import TunerEngine

/// The live Tuner screen — the real `TunerEngine` driving the Aurora strobe via
/// `LiveTunerModel`, **replacing** the simulator on this tab (the Strobe tab keeps
/// the interactive `StrobeLab` simulator). Phase-driven scroll (`phaseScroll: true`)
/// uses the engine's live phase for true-strobe motion (Plan 01 wiring).
///
/// Live capture can't run in CI (no audio device) — it compiles here and runs
/// on-device; `LiveTunerModel` surfaces availability/permission issues as status.
struct LiveTunerScreen: View {
    @State private var model = LiveTunerModel()

    private var state: TunerVisualState { TunerVisualState.from(cents: model.cents) }

    var body: some View {
        ZStack {
            ScreenBackground()
            StrobeField(input: model.strobeInput, idle: model.idle, phaseScroll: true)
            readouts
            VStack { Spacer(); controls }
        }
        .lumaGlow(state)
        .foregroundStyle(Color.lumaInk)
        .task { await model.start() }
        .onDisappear { model.stop() }
    }

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

    private var controls: some View {
        VStack(spacing: Space.s4) {
            Text(model.status)
                .font(LumaFont.mono(11))
                .foregroundStyle(Color.lumaDim)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)

            HStack {
                Button { Task { await model.toggle() } } label: {
                    Label(model.running ? "Stop" : "Start",
                          systemImage: model.running ? "stop.fill" : "mic.fill")
                }
                .buttonStyle(EdgeButtonStyle(active: model.running))

                Spacer()

                Text("A4 \(Int(model.a4))")
                    .font(LumaFont.mono(11)).monospacedDigit()
                    .foregroundStyle(Color.lumaDim)
                Stepper("A4", value: a4Binding, in: 430...450, step: 1)
                    .labelsHidden()
                    .frame(maxWidth: 100)
            }
        }
        .padding(Space.s5)
        .background(Color.lumaSurface.opacity(0.55),
                    in: RoundedRectangle(cornerRadius: Radius.r4, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: Radius.r4, style: .continuous)
            .stroke(Color.lumaLine, lineWidth: 1))
        .padding(Space.s5)
    }

    private var a4Binding: Binding<Double> {
        Binding(get: { model.a4 }, set: { model.a4 = $0 })
    }
}

#if DEBUG
#Preview("Live Tuner — dark") {
    LiveTunerScreen().preferredColorScheme(.dark)
}
#endif
