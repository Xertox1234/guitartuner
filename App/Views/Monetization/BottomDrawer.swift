import SwiftUI
import LumaDesignSystem

/// The persistent bottom drawer: always peeked at 80 pt, swipe up for cards/store.
struct BottomDrawer: View {
    var model: LiveTunerModel
    @Bindable var cardStore: TuningCardStore
    @Bindable var accountModel: AccountModel
    @Bindable var gearStore: GearStoreModel

    @State private var showAccount = false
    @State private var showSaveCard = false
    @State private var showGearStore = false
    @Binding var detent: PresentationDetent

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                dragHandle

                switch detent {
                case .height(80):
                    peekContent
                default:
                    expandedContent
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
            .background(Color(.systemBackground).opacity(0.95))
        }
        .sheet(isPresented: $showAccount) {
            AccountSheet(accountModel: accountModel)
        }
        .sheet(isPresented: $showSaveCard) {
            SaveCardSheet(model: model, cardStore: cardStore, accountModel: accountModel)
        }
        .fullScreenCover(isPresented: $showGearStore) {
            GearStoreScreen(gearStore: gearStore)
        }
        .task { await cardStore.fetch() }
    }

    // MARK: - Peek strip

    private var dragHandle: some View {
        Capsule()
            .fill(Color.secondary.opacity(0.4))
            .frame(width: 36, height: 4)
            .padding(.top, 10)
            .padding(.bottom, 8)
    }

    private var peekContent: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 10) {
                ForEach(cardStore.cards) { card in
                    CardChip(card: card)
                        .onTapGesture { loadCard(card) }
                }
                addChip
            }
            .padding(.horizontal, 16)
            .padding(.bottom, 12)
        }
    }

    // MARK: - Expanded content

    private var expandedContent: some View {
        VStack(alignment: .leading, spacing: 0) {
            header
            if cardStore.cards.isEmpty {
                emptyState
            } else {
                cardGrid
            }
            if !accountModel.isSignedIn {
                signInNudge
            }
        }
        .padding(.horizontal, 16)
    }

    private var header: some View {
        HStack {
            Text("MY TUNINGS")
                .font(.caption.bold())
                .foregroundStyle(.secondary)
                .kerning(1)
            Spacer()
            Button("+ Save Current") { handleSave() }
                .font(.caption.bold())
                .foregroundStyle(Color.lumaInTune)
            Button { showGearStore = true } label: {
                Label("Store", systemImage: "bag")
                    .font(.caption)
            }
            .foregroundStyle(.secondary)
        }
        .padding(.vertical, 12)
    }

    private var cardGrid: some View {
        LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 10) {
            ForEach(cardStore.cards) { card in
                TuningCardCell(card: card)
                    .onTapGesture { loadCard(card) }
                    .contextMenu {
                        Button(role: .destructive) {
                            Task { try? await cardStore.delete(card) }
                        } label: {
                            Label("Delete", systemImage: "trash")
                        }
                    }
            }
            addCardCell
        }
        .padding(.bottom, 20)
    }

    private var addChip: some View {
        Button { handleSave() } label: {
            Image(systemName: "plus")
                .frame(width: 40, height: 36)
                .background(Color.secondary.opacity(0.12), in: RoundedRectangle(cornerRadius: 8))
                .foregroundStyle(.secondary)
        }
    }

    private var addCardCell: some View {
        Button { handleSave() } label: {
            VStack(spacing: 6) {
                Image(systemName: "plus")
                    .font(.title3)
                Text("Save tuning")
                    .font(.caption2)
            }
            .foregroundStyle(.secondary)
            .frame(maxWidth: .infinity, minHeight: 70)
            .background(Color.secondary.opacity(0.06), in: RoundedRectangle(cornerRadius: 10))
        }
    }

    private var emptyState: some View {
        VStack(spacing: 8) {
            Image(systemName: "music.note.list")
                .font(.largeTitle)
                .foregroundStyle(.secondary)
            Text("No saved tunings yet")
                .font(.subheadline)
                .foregroundStyle(.secondary)
            Button("Save Current Tuning") { handleSave() }
                .buttonStyle(.borderedProminent)
                .tint(.lumaInTune)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 32)
    }

    private var signInNudge: some View {
        Text("Sign in to sync tunings across devices")
            .font(.caption)
            .foregroundStyle(.secondary)
            .frame(maxWidth: .infinity, alignment: .center)
            .padding(.bottom, 16)
    }

    // MARK: - Actions

    private func handleSave() {
        if accountModel.isSignedIn { showSaveCard = true }
        else { showAccount = true }
    }

    private func loadCard(_ card: TuningCard) {
        model.setInstrument(card.instrument)
        model.setTuning(card.tuning)
        model.a4 = card.a4
        // Note: palette is @AppStorage — set via UserDefaults key "strobePalette"
        UserDefaults.standard.set(card.palette.rawValue, forKey: "strobePalette")
    }
}

// MARK: - Sub-views

struct CardChip: View {
    let card: TuningCard
    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(card.name)
                .font(.caption.bold())
                .foregroundStyle(paletteColor(card.palette))
            Text("\(card.instrument == .guitar ? "Guitar" : "Bass") · \(Int(card.a4))")
                .font(.caption2)
                .foregroundStyle(.secondary)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .background(paletteColor(card.palette).opacity(0.12), in: RoundedRectangle(cornerRadius: 8))
        .overlay(RoundedRectangle(cornerRadius: 8).strokeBorder(paletteColor(card.palette).opacity(0.3)))
    }
}

struct TuningCardCell: View {
    let card: TuningCard
    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(card.name)
                .font(.caption.bold())
                .foregroundStyle(paletteColor(card.palette))
            Text("\(card.instrument == .guitar ? "Guitar" : "Bass") · \(Int(card.a4)) Hz · \(card.palette.label)")
                .font(.caption2)
                .foregroundStyle(.secondary)
            HStack(spacing: 4) {
                ForEach(card.strings.prefix(4)) { s in
                    Text(s.note)
                        .font(.system(size: 9, design: .monospaced))
                        .padding(.horizontal, 4).padding(.vertical, 2)
                        .background(paletteColor(card.palette).opacity(0.15), in: RoundedRectangle(cornerRadius: 3))
                        .foregroundStyle(paletteColor(card.palette))
                }
            }
        }
        .padding(10)
        .frame(maxWidth: .infinity, minHeight: 70, alignment: .topLeading)
        .background(paletteColor(card.palette).opacity(0.08), in: RoundedRectangle(cornerRadius: 10))
        .overlay(RoundedRectangle(cornerRadius: 10).strokeBorder(paletteColor(card.palette).opacity(0.2)))
    }
}

private func paletteColor(_ palette: LumaPalette) -> Color {
    switch palette {
    case .aurora:  return .lumaInTune
    case .amber:   return Color(hue: 0.1, saturation: 0.8, brightness: 0.9)
    case .neon:    return Color(hue: 0.75, saturation: 0.8, brightness: 0.9)
    case .forest:  return Color(hue: 0.35, saturation: 0.7, brightness: 0.7)
    case .crimson: return Color(hue: 0.0, saturation: 0.8, brightness: 0.85)
    }
}
