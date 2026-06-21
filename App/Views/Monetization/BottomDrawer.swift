#if os(iOS)
import SwiftUI
import LumaDesignSystem

/// The persistent bottom drawer: always peeked at 80 pt, swipe up for cards/store.
struct BottomDrawer: View {
    var model: LiveTunerModel
    @Bindable var cardStore: TuningCardStore
    @Bindable var accountModel: AccountModel
    @Bindable var gearStore: GearStoreModel

    @Binding var palette: LumaPalette
    @State private var showAccount = false
    @State private var showSaveCard = false
    @State private var showGearStore = false
    @State private var showSignOutConfirm = false
    @State private var showDeleteConfirm = false
    @State private var deleteError: String? = nil
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
            accountStatus
        }
        .padding(.horizontal, 16)
    }

    private var header: some View {
        HStack {
            Text("MY TUNINGS")
                .lumaUIFont(LumaFont.Size.cap, weight: .bold)
                .foregroundStyle(.secondary)
                .kerning(1)
            Spacer()
            Button("+ Save Current") { handleSave() }
                .lumaUIFont(LumaFont.Size.cap, weight: .bold)
                .foregroundStyle(Color.lumaInTune)
            Button { showGearStore = true } label: {
                Label("Store", systemImage: "bag")
                    .lumaUIFont(LumaFont.Size.cap)
            }
            .foregroundStyle(.secondary)
            Button {
                if accountModel.isSignedIn { showSignOutConfirm = true }
                else { showAccount = true }
            } label: {
                Image(systemName: accountModel.isSignedIn ? "person.circle.fill" : "person.circle")
                    .foregroundStyle(accountModel.isSignedIn ? Color.lumaInTune : Color.secondary)
            }
        }
        .padding(.vertical, 12)
        .confirmationDialog("Account", isPresented: $showSignOutConfirm) {
            Button("Sign Out", role: .destructive) {
                Task { await accountModel.signOut() }
            }
            Button("Delete Account", role: .destructive) {
                // Deferred to avoid SwiftUI chained-dialog drop bug
                Task { @MainActor in showDeleteConfirm = true }
            }
            Button("Cancel", role: .cancel) {}
        }
        .confirmationDialog(
            "Permanently Delete Account?",
            isPresented: $showDeleteConfirm,
            titleVisibility: .visible
        ) {
            Button("Delete My Account and Data", role: .destructive) {
                Task {
                    do { try await accountModel.deleteAccount() }
                    catch { deleteError = error.localizedDescription }
                }
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("This will permanently delete your account and all saved tunings. This cannot be undone.")
        }
        .alert("Could Not Delete Account", isPresented: Binding(
            get: { deleteError != nil },
            set: { if !$0 { deleteError = nil } }
        )) {
            Button("OK") { deleteError = nil }
        } message: {
            Text(deleteError ?? "")
        }
    }

    private var cardGrid: some View {
        LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 10) {
            ForEach(cardStore.cards) { card in
                TuningCardCell(card: card)
                    .onTapGesture { loadCard(card) }
                    .contextMenu {
                        Button(role: .destructive) {
                            Task {
                                do {
                                    try await cardStore.delete(card)
                                } catch {
                                    cardStore.error = error.localizedDescription
                                }
                            }
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
                    .lumaUIFont(LumaFont.Size.xl)
                Text("Save tuning")
                    .lumaUIFont(LumaFont.Size.micro)
            }
            .foregroundStyle(.secondary)
            .frame(maxWidth: .infinity, minHeight: 70)
            .background(Color.secondary.opacity(0.06), in: RoundedRectangle(cornerRadius: 10))
        }
    }

    private var emptyState: some View {
        VStack(spacing: 8) {
            Image(systemName: "music.note.list")
                .lumaUIFont(LumaFont.Size.xl3)
                .foregroundStyle(.secondary)
            Text("No saved tunings yet")
                .lumaUIFont(LumaFont.Size.body)
                .foregroundStyle(.secondary)
            Button("Save Current Tuning") { handleSave() }
                .buttonStyle(.borderedProminent)
                .tint(.lumaInTune)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 32)
    }

    private var accountStatus: some View {
        Group {
            if accountModel.isSignedIn {
                HStack(spacing: 6) {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundStyle(Color.lumaInTune)
                    Text("Signed in")
                        .foregroundStyle(.secondary)
                    Spacer()
                    Button("Sign out") { showSignOutConfirm = true }
                        .foregroundStyle(.secondary)
                }
                .lumaUIFont(LumaFont.Size.cap)
                .frame(maxWidth: .infinity)
                .padding(.bottom, 16)
            } else {
                Button {
                    showAccount = true
                } label: {
                    Text("Sign in to sync tunings across devices")
                        .lumaUIFont(LumaFont.Size.cap)
                        .foregroundStyle(Color.lumaInTune)
                        .frame(maxWidth: .infinity, alignment: .center)
                        .padding(.bottom, 16)
                }
            }
        }
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
        palette = card.palette
    }
}

// MARK: - Sub-views

struct CardChip: View {
    let card: TuningCard
    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(card.name)
                .lumaUIFont(LumaFont.Size.cap, weight: .bold)
                .foregroundStyle(card.palette.color)
            Text("\(card.instrument == .guitar ? "Guitar" : "Bass") · \(Int(card.a4))")
                .lumaUIFont(LumaFont.Size.micro)
                .foregroundStyle(.secondary)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .background(card.palette.color.opacity(0.12), in: RoundedRectangle(cornerRadius: 8))
        .overlay(RoundedRectangle(cornerRadius: 8).strokeBorder(card.palette.color.opacity(0.3)))
    }
}

struct TuningCardCell: View {
    let card: TuningCard
    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(card.name)
                .lumaUIFont(LumaFont.Size.cap, weight: .bold)
                .foregroundStyle(card.palette.color)
            Text("\(card.instrument == .guitar ? "Guitar" : "Bass") · \(Int(card.a4)) Hz · \(card.palette.label)")
                .lumaUIFont(LumaFont.Size.micro)
                .foregroundStyle(.secondary)
            HStack(spacing: 4) {
                ForEach(card.strings.prefix(4)) { s in
                    Text(s.note)
                        .font(.system(size: 9, design: .monospaced))
                        .padding(.horizontal, 4).padding(.vertical, 2)
                        .background(card.palette.color.opacity(0.15), in: RoundedRectangle(cornerRadius: 3))
                        .foregroundStyle(card.palette.color)
                }
            }
        }
        .padding(10)
        .frame(maxWidth: .infinity, minHeight: 70, alignment: .topLeading)
        .background(card.palette.color.opacity(0.08), in: RoundedRectangle(cornerRadius: 10))
        .overlay(RoundedRectangle(cornerRadius: 10).strokeBorder(card.palette.color.opacity(0.2)))
    }
}


#Preview("Bottom Drawer — peek") {
    @Previewable @State var detent: PresentationDetent = .height(80)
    @Previewable @State var palette: LumaPalette = .aurora
    BottomDrawer(
        model: LiveTunerModel(),
        cardStore: TuningCardStore(),
        accountModel: AccountModel(),
        gearStore: GearStoreModel(),
        palette: $palette,
        detent: $detent
    )
}

#Preview("Bottom Drawer — expanded") {
    @Previewable @State var detent: PresentationDetent = .medium
    @Previewable @State var palette: LumaPalette = .aurora
    BottomDrawer(
        model: LiveTunerModel(),
        cardStore: TuningCardStore(),
        accountModel: AccountModel(),
        gearStore: GearStoreModel(),
        palette: $palette,
        detent: $detent
    )
}
#endif
