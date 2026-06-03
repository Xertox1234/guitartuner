import SwiftUI

/// Top edge chrome — brand on the left, input source + settings on the right.
/// Mirrors `.scr-top` in `ds-components.css`.
public struct ScreenTop: View {
    @Binding var source: InputKind
    var onSettings: () -> Void

    public init(source: Binding<InputKind>, onSettings: @escaping () -> Void = {}) {
        self._source = source
        self.onSettings = onSettings
    }

    public var body: some View {
        HStack {
            Brand()
            Spacer()
            HStack(spacing: Space.s3) {
                InputSource(source: $source)
                SettingsButton(action: onSettings)
            }
        }
        .padding(.horizontal, Space.s6)
        .padding(.top, Space.s5)
        .padding(.bottom, Space.s3)
    }
}

/// The controls dock — target chip (centered), string row, and the A4 / tone
/// utility strip. Mirrors `.dock` / `.util` in `ds-components.css`.
public struct ControlsDock: View {
    let tuning: Tuning
    @Binding var mode: TargetMode
    @Binding var activeIdx: Int?
    var lockedIdx: Int?
    @Binding var a4: Int
    @Binding var toneOn: Bool

    public init(
        tuning: Tuning,
        mode: Binding<TargetMode>,
        activeIdx: Binding<Int?>,
        lockedIdx: Int? = nil,
        a4: Binding<Int>,
        toneOn: Binding<Bool>
    ) {
        self.tuning = tuning
        self._mode = mode
        self._activeIdx = activeIdx
        self.lockedIdx = lockedIdx
        self._a4 = a4
        self._toneOn = toneOn
    }

    public var body: some View {
        VStack(spacing: Space.s4) {
            TargetChip(mode: $mode)
            StringRow(tuning: tuning, activeIdx: $activeIdx, lockedIdx: lockedIdx)
            HStack {
                A4Control(a4: $a4)
                Spacer()
                ToneToggle(on: $toneOn)
            }
            .padding(.top, Space.s2)
        }
        .padding(.horizontal, Space.s6)
        .padding(.top, Space.s4)
        .padding(.bottom, Space.s7)
    }
}

/// The full LUMA tuner screen composed statically — top chrome over a hero field
/// (the field wash; the Metal strobe lands in Plan 03) over the controls dock.
/// Drive it with a forced state via `cents` (`nil` = idle/standby). No DSP.
public struct TunerScreenStatic: View {
    var instrument: Instrument
    var note: String
    var octave: Int
    /// Signed cents, or `nil` for the idle/standby state.
    var cents: Double?

    @State private var source: InputKind
    @State private var mode: TargetMode
    @State private var activeIdx: Int?
    @State private var a4: Int
    @State private var toneOn: Bool

    public init(
        instrument: Instrument = .guitar,
        note: String = "A",
        octave: Int = 2,
        cents: Double? = -6,
        mode: TargetMode = .auto,
        activeIdx: Int? = nil,
        a4: Int = 440,
        toneOn: Bool = false,
        source: InputKind = .di
    ) {
        self.instrument = instrument
        self.note = note
        self.octave = octave
        self.cents = cents
        _mode = State(initialValue: mode)
        _activeIdx = State(initialValue: activeIdx)
        _a4 = State(initialValue: a4)
        _toneOn = State(initialValue: toneOn)
        _source = State(initialValue: source)
    }

    private var state: TunerVisualState { TunerVisualState.from(cents: cents) }
    private var tuning: Tuning { Tunings.standard(for: instrument) }
    private var locked: Bool { state == .tune }
    private var lockedIdx: Int? { (locked && mode == .lock) ? activeIdx : nil }

    private var displayedFreq: Double {
        let nIndex = LumaMusic.names.firstIndex(of: note) ?? 9
        let midi = (octave + 1) * 12 + nIndex
        let base = LumaMusic.frequency(midi: midi, a4: Double(a4))
        return base * pow(2, (cents ?? 0) / 1200)
    }

    public var body: some View {
        ZStack {
            ScreenBackground()
            VStack(spacing: 0) {
                ScreenTop(source: $source)

                // Hero field — note stack over the Aurora strobe (Plan 03).
                ZStack {
                    StrobeField(input: StrobeInput(cents: cents ?? 0, locked: locked), idle: cents == nil)
                    VStack(spacing: 0) {
                        NoteReadout(note: note, octave: octave, locked: locked, dimmed: cents == nil)
                        if let cents {
                            CentsReadout(cents: cents, state: state)
                                .padding(.top, Space.s5)
                            StateLine(state: state)
                                .padding(.top, Space.s4)
                            FreqLine(freq: displayedFreq)
                                .padding(.top, Space.s3)
                        } else {
                            StateLine(state: .idle)
                                .padding(.top, Space.s6)
                        }
                    }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)

                ControlsDock(
                    tuning: tuning,
                    mode: $mode,
                    activeIdx: $activeIdx,
                    lockedIdx: lockedIdx,
                    a4: $a4,
                    toneOn: $toneOn
                )
            }
        }
        .lumaGlow(state)
        .animation(.easeInOut(duration: 0.4), value: state)
        .foregroundStyle(Color.lumaInk)
    }
}

#if DEBUG
#Preview("Tuner — flat · dark") {
    TunerScreenStatic(note: "A", octave: 2, cents: -6)
        .preferredColorScheme(.dark)
}

#Preview("Tuner — in tune · dark") {
    TunerScreenStatic(note: "E", octave: 4, cents: 0, mode: .lock, activeIdx: 1)
        .preferredColorScheme(.dark)
}

#Preview("Tuner — idle · light") {
    TunerScreenStatic(note: "A", octave: 2, cents: nil)
        .preferredColorScheme(.light)
}

#Preview("Tuner — sharp · light") {
    TunerScreenStatic(note: "D", octave: 3, cents: 7)
        .preferredColorScheme(.light)
}
#endif
