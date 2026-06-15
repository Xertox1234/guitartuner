import SwiftUI
import LumaDesignSystem
#if canImport(UIKit)
import UIKit
#endif

/// The live Tuner screen — the real `TunerEngine` driving the Aurora strobe via
/// `LiveTunerModel`, with the full LUMA layout: top chrome, the hero strobe + note
/// stack, and the controls dock (Auto/String-lock toggle, string row, tone). A4
/// calibration and tuning presets live in the Settings sheet. Phase-driven scroll
/// (`phaseScroll: true`) uses the engine's live phase for true-strobe motion.
///
/// Live capture can't run in CI (no audio device) — it compiles here and runs
/// on-device; `LiveTunerModel` surfaces availability/permission issues as status.
struct LiveTunerScreen: View {
    /// Shared with the menu-bar strobe; owned by `LumaApp`.
    @Bindable var model: LiveTunerModel
    var accountModel: AccountModel
    var cardStore: TuningCardStore
    var gearStore: GearStoreModel
    @State private var drawerDetent: PresentationDetent = .height(80)
    @State private var showSettings = false
    /// Full-screen, max-contrast Stage Mode (EXPERIENCE §8).
    @State private var stageMode = false
    /// Persisted hero-strobe choice (Aurora default); shared with the Settings sheet
    /// via the same key. Reduce Motion still overrides to the still gauge.
    @AppStorage("strobeStyle") private var strobeStyle: StrobeStyle = .aurora
    /// Optional waveform scope under the readouts (off by default).
    @AppStorage("showScope") private var showScope = false
    /// Opt-in Metal hero renderer for the Aurora field (experimental; validate on-device).
    @AppStorage("useMetalStrobe") private var useMetalStrobe = false
    /// Persisted strobe colour palette (Aurora default); shared with Settings via the same key.
    @AppStorage("strobePalette") private var palette: LumaPalette = .aurora
    @Environment(\.openURL) private var openURL
    @Environment(\.colorScheme) private var colorScheme

    private var state: TunerVisualState { TunerVisualState.from(cents: model.cents, locked: model.strobeInput.locked) }

    /// The string cell glows mint only when we're locked *onto that target*.
    private var lockedIdx: Int? {
        (model.mode == .lock && state == .tune) ? model.activeIdx : nil
    }

    var body: some View {
        ZStack {
            StrobeField(input: model.strobeInput, idle: model.idle, style: strobeStyle,
                        phaseScroll: true, useMetalRenderer: useMetalStrobe)
            VStack(spacing: 0) {
                topChrome
                Spacer(minLength: Space.s4)
                readouts
                Spacer(minLength: Space.s4)
                if showScope {
                    Oscilloscope(freq: model.frequency, cents: model.cents ?? 0,
                                 state: state, active: !model.idle)
                        .frame(height: 56)
                        .frame(maxWidth: 420)
                        .padding(.horizontal, Space.s6)
                        .padding(.bottom, Space.s4)
                        .allowsHitTesting(false)
                }
                dock
            }

            if stageMode {
                StageView(input: model.strobeInput, note: model.note, octave: model.octave,
                          cents: model.cents, idle: model.idle, style: strobeStyle, phaseScroll: true) {
                    withAnimation(.easeInOut(duration: 0.3)) { stageMode = false }
                }
                .transition(.opacity)
                .zIndex(1)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background { ScreenBackground() }
        .lumaPalette(palette)
        .lumaGlow(state.glow(palette: palette, scheme: colorScheme))
        .foregroundStyle(Color.lumaInk)
        .task { await model.start() }
        .onChange(of: stageMode) { _, active in setStageHold(active) }
        .onDisappear { setStageHold(false); model.stop() }
        .sheet(isPresented: $showSettings) { SettingsView(model: model) }
        #if os(iOS)
        .sheet(isPresented: .constant(true)) {
            BottomDrawer(
                model: model,
                cardStore: cardStore,
                accountModel: accountModel,
                gearStore: gearStore,
                detent: $drawerDetent
            )
            .presentationDetents([.height(80), .medium, .fraction(0.9)], selection: $drawerDetent)
            .presentationBackgroundInteraction(.enabled(upThrough: .height(80)))
            .interactiveDismissDisabled()
            .presentationDragIndicator(.visible)
            .presentationCornerRadius(16)
        }
        #endif
    }

    /// Keep the screen awake while Stage Mode is up (a propped-on-the-amp prop
    /// shouldn't dim/sleep). iOS-only; a clean no-op elsewhere.
    private func setStageHold(_ active: Bool) {
        #if canImport(UIKit)
        UIApplication.shared.isIdleTimerDisabled = active
        #endif
    }

    // MARK: Top chrome

    private var topChrome: some View {
        HStack {
            Brand()
            Spacer()
            HStack(spacing: Space.s3) {
                InputSource(source: inputBinding)
                EdgeIconButton(systemImage: "arrow.up.left.and.arrow.down.right",
                               accessibilityLabel: "Stage Mode") {
                    withAnimation(.easeInOut(duration: 0.3)) { stageMode = true }
                }
                SettingsButton { showSettings = true }
            }
        }
        .padding(.horizontal, Space.s6)
        .padding(.top, Space.s5)
        .padding(.bottom, Space.s4)
        .background(
            LinearGradient(
                stops: [
                    .init(color: Color.lumaBg.opacity(0.65), location: 0),
                    .init(color: .clear, location: 1)
                ],
                startPoint: .top,
                endPoint: .bottom
            )
            .ignoresSafeArea(edges: .top)
        )
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

            // Mic access denied is otherwise a dead end — deep-link to the
            // system's privacy pane so re-granting is one tap away.
            if model.permissionDenied, let url = microphoneSettingsURL {
                Button("Open Settings") { openURL(url) }
                    .font(LumaFont.mono(11))
                    .buttonStyle(.bordered)
                    .tint(.lumaInTune)
            }
        }
        .padding(Space.s5)
        .background(Color.lumaSurface.opacity(0.55),
                    in: RoundedRectangle(cornerRadius: Radius.r4, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: Radius.r4, style: .continuous)
            .stroke(Color.lumaLine, lineWidth: 1))
        .padding(.horizontal, Space.s5)
        .padding(.bottom, Space.s5)
    }

    /// Where to send the user to re-grant mic access: the app's own page in
    /// Settings on iOS, the Privacy → Microphone pane on macOS.
    private var microphoneSettingsURL: URL? {
        #if os(iOS)
        URL(string: UIApplication.openSettingsURLString)
        #elseif os(macOS)
        URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Microphone")
        #else
        nil
        #endif
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
    LiveTunerScreen(model: LiveTunerModel(), accountModel: AccountModel(), cardStore: TuningCardStore(), gearStore: GearStoreModel())
        .preferredColorScheme(.dark)
        .previewDevice(PreviewDevice(rawValue: "iPhone 16"))
}
#endif
