import SwiftUI
import LumaDesignSystem

/// Presented after successful auth. Captures a name + notes for the current tuner state.
struct SaveCardSheet: View {
    var model: LiveTunerModel
    @Bindable var cardStore: TuningCardStore
    @Bindable var accountModel: AccountModel
    @Environment(\.dismiss) private var dismiss

    @AppStorage("strobePalette") private var palette: LumaPalette = .aurora
    @State private var name: String = ""
    @State private var notes: String = ""
    @State private var isSaving = false
    @State private var errorMessage: String?

    var body: some View {
        NavigationStack {
            Form {
                Section("Name") {
                    TextField("e.g. Open G (Nashville)", text: $name)
                }

                Section("Notes (optional)") {
                    TextField("Great for slide, capo 5…", text: $notes, axis: .vertical)
                        .lineLimit(2...4)
                }

                Section {
                    snapshotPreview
                } header: {
                    Text("Saving With")
                } footer: {
                    Text("One tap on the card restores all of these settings.")
                }

                if let err = errorMessage {
                    Section { Text(err).foregroundStyle(.red).font(LumaFont.ui(LumaFont.Size.cap)) }
                }

                Section {
                    Button {
                        Task { await save() }
                    } label: {
                        if isSaving {
                            ProgressView()
                        } else {
                            Text("Save Card").frame(maxWidth: .infinity)
                        }
                    }
                    .disabled(name.trimmingCharacters(in: .whitespaces).isEmpty || isSaving)
                }
            }
            .navigationTitle("Save Tuning")
            #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
            #endif
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
            }
        }
        .tint(.lumaInTune)
        .onAppear { prefillName() }
    }

    private var snapshotPreview: some View {
        Grid(alignment: .leading, horizontalSpacing: 12, verticalSpacing: 4) {
            GridRow {
                Text("Instrument").foregroundStyle(.secondary)
                Text(model.instrument == .guitar ? "Guitar" : "Bass")
            }
            GridRow {
                Text("Tuning").foregroundStyle(.secondary)
                Text(model.tuning.label)
            }
            GridRow {
                Text("A4").foregroundStyle(.secondary)
                Text("\(Int(model.a4)) Hz")
            }
            GridRow {
                Text("Palette").foregroundStyle(.secondary)
                Text(palette.label).foregroundStyle(palette.color)
            }
        }
        .font(LumaFont.ui(LumaFont.Size.body))
    }

    private func prefillName() {
        if name.isEmpty { name = model.tuning.label }
    }

    private func save() async {
        isSaving = true; defer { isSaving = false }
        errorMessage = nil
        do {
            try await cardStore.save(
                name: name.trimmingCharacters(in: .whitespaces),
                notes: notes,
                instrument: model.instrument,
                a4: model.a4,
                palette: palette,
                strings: model.tuning.strings
            )
            dismiss()
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}

