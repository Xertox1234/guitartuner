import SwiftUI
import LumaDesignSystem
import TunerEngine

/// The Settings sheet: reference calibration (A4), instrument + tuning preset, the
/// in-tune haptic toggle, and the privacy note. A native `Form` so Dynamic Type and
/// VoiceOver come for free; tinted to the LUMA accent. Reached from the gear in the
/// Tuner screen's top chrome.
struct SettingsView: View {
    @Bindable var model: LiveTunerModel
    @Environment(\.dismiss) private var dismiss
    /// Hero-strobe choice, shared with `LiveTunerScreen` via the same `@AppStorage` key.
    @AppStorage("strobeStyle") private var strobeStyle: StrobeStyle = .aurora
    /// Optional waveform scope under the readouts (off by default).
    @AppStorage("showScope") private var showScope = false

    var body: some View {
        NavigationStack {
            Form {
                Section("Reference") {
                    HStack {
                        Text("Calibration")
                        Spacer()
                        A4Control(a4: a4Binding)
                    }
                    .accessibilityElement(children: .contain)
                }

                Section("Instrument") {
                    Picker("Instrument", selection: instrumentBinding) {
                        ForEach(Instrument.allCases) { inst in
                            Text(inst == .guitar ? "Guitar" : "Bass").tag(inst)
                        }
                    }
                    .pickerStyle(.segmented)

                    Picker("Tuning", selection: tuningBinding) {
                        ForEach(Tunings.presets(for: model.instrument)) { preset in
                            Text(preset.label).tag(preset.id)
                        }
                    }
                }

                Section {
                    Picker("Strobe", selection: $strobeStyle) {
                        ForEach(StrobeStyle.allCases) { style in
                            Text(style.label).tag(style)
                        }
                    }
                    .pickerStyle(.segmented)

                    Toggle("Oscilloscope", isOn: $showScope)
                } header: {
                    Text("Display")
                } footer: {
                    Text("The hero strobe, plus an optional waveform scope under the readouts. Reduce Motion replaces the strobe with a still gauge.")
                }

                Section("Feel") {
                    Toggle("In-tune haptic", isOn: $model.hapticsEnabled)
                }

                Section {
                    Text("All audio is analyzed entirely on your device. Your playing is never recorded, stored, or sent — LUMA does no networking.")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                } header: {
                    Text("Privacy")
                }
            }
            .navigationTitle("Settings")
            #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
            #endif
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                }
            }
        }
        .tint(.lumaInTune)
        #if os(iOS)
        .presentationDetents([.medium, .large])
        #endif
    }

    // MARK: Bindings

    private var a4Binding: Binding<Int> {
        Binding(get: { Int(model.a4.rounded()) }, set: { model.a4 = Double($0) })
    }

    private var instrumentBinding: Binding<Instrument> {
        Binding(get: { model.instrument }, set: { model.setInstrument($0) })
    }

    /// Selected by tuning `id`; resolves back to the matching preset.
    private var tuningBinding: Binding<String> {
        Binding(
            get: { model.tuning.id },
            set: { id in
                if let preset = Tunings.presets(for: model.instrument).first(where: { $0.id == id }) {
                    model.setTuning(preset)
                }
            }
        )
    }
}
