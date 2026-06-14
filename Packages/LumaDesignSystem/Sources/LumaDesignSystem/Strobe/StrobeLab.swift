import SwiftUI
import Combine
import QuartzCore

/// Interactive harness for the Aurora strobe prototype — full-bleed strobe +
/// the Plan 02 readouts + a cents slider, pluck, string row, instrument picker,
/// a Reduce-Motion toggle (to preview the gauge), a theme toggle, and an fps
/// readout. Mirrors `prototypes/strobe-concepts.html`. No audio engine — driven
/// by `TunerSimulator`.
public struct StrobeLab: View {
    @State private var sim = TunerSimulator()
    @State private var scheme: ColorScheme = .dark
    @State private var reduceMotion = false
    @State private var style: StrobeStyle = .aurora
    @State private var palette: LumaPalette = .aurora
    @State private var useMetal = false

    // Physics tick, off the view-update path (advancing @Observable inside body
    // would trip "modifying state during view update").
    private let physics = Timer.publish(every: 1.0 / 120.0, on: .main, in: .common).autoconnect()

    public init() {}

    private var state: TunerVisualState { TunerVisualState.from(cents: sim.cents, locked: sim.input.locked) }

    public var body: some View {
        ZStack {
            ScreenBackground()
            StrobeField(input: sim.input, style: style, forceReduceMotion: reduceMotion, useMetalRenderer: useMetal)
            readouts
            VStack {
                Spacer()
                controls
            }
        }
        .lumaGlow(state)
        .lumaPalette(palette)
        .environment(\.colorScheme, scheme)
        .foregroundStyle(Color.lumaInk)
        .onReceive(physics) { _ in sim.advance(to: CACurrentMediaTime()) }
    }

    // MARK: Readouts (reused Plan 02 components)

    private var readouts: some View {
        VStack(spacing: 0) {
            NoteReadout(note: sim.activeString.note, octave: sim.activeString.octave, locked: sim.locked)
            CentsReadout(cents: sim.cents, state: state)
                .padding(.top, Space.s5)
            StateLine(state: state)
                .padding(.top, Space.s4)
            FreqLine(freq: sim.displayedFrequency())
                .padding(.top, Space.s3)
        }
        .allowsHitTesting(false)
    }

    // MARK: Controls

    private var controls: some View {
        VStack(spacing: Space.s4) {
            HStack(spacing: Space.s3) {
                Text("CENTS").font(LumaFont.mono(10)).foregroundStyle(Color.lumaDim)
                Slider(value: centsBinding, in: -50...50)
                    .tint(state.glow)
                Text("\(Int(sim.cents.rounded()))")
                    .font(LumaFont.mono(11)).monospacedDigit()
                    .foregroundStyle(Color.lumaInk).frame(width: 34, alignment: .trailing)
            }

            StringRow(
                tuning: sim.tuning,
                activeIdx: .constant(Optional(sim.stringIdx)),
                lockedIdx: sim.locked ? sim.stringIdx : nil,
                onPick: { sim.pluck($0) }
            )

            HStack {
                Button { sim.pluck() } label: { Label("Pluck", systemImage: "hand.tap") }
                    .buttonStyle(EdgeButtonStyle())
                Spacer()
                FPSReadout()
                Spacer()
                Picker("Instrument", selection: instrumentBinding) {
                    Text("Guitar").tag(Instrument.guitar)
                    Text("Bass").tag(Instrument.bass)
                }
                .pickerStyle(.segmented)
                .frame(width: 150)
                .labelsHidden()
            }

            HStack(spacing: Space.s3) {
                Text("STROBE").font(LumaFont.mono(10)).foregroundStyle(Color.lumaDim)
                Picker("Strobe", selection: $style) {
                    ForEach(StrobeStyle.allCases) { Text($0.label).tag($0) }
                }
                .pickerStyle(.segmented)
                .labelsHidden()
                Toggle(isOn: $useMetal) {
                    Text("Metal").font(LumaFont.mono(10)).foregroundStyle(Color.lumaDim)
                }
                .toggleStyle(.switch)
                .tint(.lumaInTune)
                .fixedSize()
            }

            HStack(spacing: Space.s3) {
                Text("PALETTE").font(LumaFont.mono(10)).foregroundStyle(Color.lumaDim)
                Picker("Palette", selection: $palette) {
                    ForEach(LumaPalette.allCases) { Text($0.label).tag($0) }
                }
                .labelsHidden()
            }

            HStack {
                Toggle(isOn: $reduceMotion) {
                    Text("Reduce Motion").font(LumaFont.mono(10)).foregroundStyle(Color.lumaDim)
                }
                .toggleStyle(.switch)
                .tint(.lumaInTune)
                Spacer()
                Button { scheme = (scheme == .dark ? .light : .dark) } label: {
                    Label(scheme == .dark ? "Light" : "Dark", systemImage: "circle.lefthalf.filled")
                }
                .buttonStyle(EdgeButtonStyle())
            }
        }
        .padding(Space.s5)
        .background(Color.lumaSurface.opacity(0.55), in: RoundedRectangle(cornerRadius: Radius.r4, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: Radius.r4, style: .continuous).stroke(Color.lumaLine, lineWidth: 1))
        .padding(Space.s5)
    }

    private var centsBinding: Binding<Double> {
        Binding(get: { sim.cents }, set: { sim.setManual($0) })
    }

    private var instrumentBinding: Binding<Instrument> {
        Binding(get: { sim.instrument }, set: { sim.setInstrument($0) })
    }
}

/// Smoothed frames-per-second readout from the display clock. Reports the
/// achieved refresh cadence; true rendering cost needs Instruments on-device.
private struct FPSReadout: View {
    @State private var holder = FPSHolder()

    var body: some View {
        TimelineView(.animation) { timeline in
            let fps = holder.update(timeline.date.timeIntervalSinceReferenceDate)
            Text(fps > 0 ? "\u{2248}\(Int(fps.rounded())) fps" : "\u{2014} fps")
                .font(LumaFont.mono(11)).monospacedDigit()
                .foregroundStyle(Color.lumaFaint)
        }
    }
}

private final class FPSHolder {
    private var last: Double = 0
    private var ema: Double = 0

    func update(_ time: Double) -> Double {
        defer { last = time }
        guard last != 0 else { return 0 }
        let dt = time - last
        guard dt > 0 else { return ema }
        let instantaneous = 1 / dt
        ema = ema == 0 ? instantaneous : ema * 0.9 + instantaneous * 0.1
        return ema
    }
}

#if DEBUG
#Preview("Strobe Lab — dark") { StrobeLab().preferredColorScheme(.dark) }
#endif
