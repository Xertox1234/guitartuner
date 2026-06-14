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
        let support = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
        self.cacheURL = support.appendingPathComponent("luma_tuning_cards.json")
        self.cards = loadCache()
    }

    // MARK: - Actions

    func fetch() async {
        isLoading = true; defer { isLoading = false }
        do {
            let response: CardsResponse = try await api.get("tunings")
            cards = response.cards
            persistCache()
        } catch {
            self.error = error.localizedDescription
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
        try? JSONEncoder().encode(cards).write(to: cacheURL, options: .atomic)
    }
}
