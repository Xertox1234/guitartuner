import Foundation
import LumaDesignSystem

@MainActor @Observable
final class TuningCardStore {
    var cards: [TuningCard] = []
    var isLoading = false
    var error: String?

    private let api: LumaAPI
    private let cacheURL: URL

    init(api: LumaAPI = LumaAPI()) {
        self.api = api
        let support = URL.applicationSupportDirectory
        self.cacheURL = support.appending(component: "luma_tuning_cards.json")
        self.cards = loadCache()
    }

    // MARK: - Actions

    func fetch() async {
        isLoading = true
        defer { isLoading = false }
        do {
            let response: CardsResponse = try await api.get("tunings")
            cards = response.cards
            persistCache()
        } catch {
            if cards.isEmpty {
                self.error = error.localizedDescription
            }
        }
    }

    // Defined here because it references TuningCard (not in APIModels.swift)
    private struct CardsResponse: Decodable { let cards: [TuningCard] }

    func save(
        name: String, notes: String,
        instrument: Instrument, a4: Double,
        palette: LumaPalette, strings: [GuitarString]
    ) async throws {
        let body = SaveCardRequest(
            name: name, notes: notes,
            instrument: instrument.rawValue,
            a4: a4, palette: palette.rawValue,
            stringsJson: TuningCard.stringsJSON(strings)
        )
        let _: SaveCardResponse = try await api.post("tunings", body: body)
        await fetch()
    }

    func delete(_ card: TuningCard) async throws {
        let _: BoolResponse = try await api.delete("tunings/\(card.id)")
        cards.removeAll { $0.id == card.id }
        persistCache()
    }

    // MARK: - Local cache

    private func loadCache() -> [TuningCard] {
        guard let data = try? Data(contentsOf: cacheURL) else { return [] }
        return (try? JSONDecoder().decode([TuningCard].self, from: data)) ?? []
    }

    private func persistCache() {
        do {
            // Application Support is not created automatically on iOS — ensure the
            // parent directory exists, or .write(to:) fails with ENOENT on first run.
            try FileManager.default.createDirectory(
                at: cacheURL.deletingLastPathComponent(),
                withIntermediateDirectories: true
            )
            try JSONEncoder().encode(cards).write(to: cacheURL, options: .atomic)
        } catch {
            // Non-fatal: stale cache on next launch; no user-visible failure.
            // (Must not crash — a debug assertionFailure here was terminating the
            // app on a fresh install before Application Support existed.)
            print("[LUMA] TuningCardStore: cache write failed — \(error)")
        }
    }
}
