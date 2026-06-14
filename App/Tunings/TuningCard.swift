import Foundation
import LumaDesignSystem

struct TuningCard: Identifiable, Codable, Hashable, Sendable {
    let id: String
    var name: String
    var notes: String
    var instrument: Instrument
    var a4: Double
    var palette: LumaPalette
    private var stringsJson: String
    let createdAt: String

    enum CodingKeys: String, CodingKey {
        case id, name, notes, instrument, a4, palette
        case stringsJson  = "strings_json"
        case createdAt    = "created_at"
    }

    /// The decoded strings array, suitable for building a `Tuning`.
    var strings: [GuitarString] {
        guard let data = stringsJson.data(using: .utf8),
              let result = try? JSONDecoder().decode([GuitarString].self, from: data) else {
            assertionFailure("TuningCard: failed to decode strings_json — card id=\(id) may be corrupt")
            return []
        }
        return result
    }

    /// A `Tuning` that can be passed directly to `LiveTunerModel.setTuning(_:)`.
    var tuning: Tuning {
        Tuning(id: "card-\(id)", label: name, strings: strings)
    }

    /// Build the strings_json from a live array (used when saving).
    static func stringsJSON(_ strings: [GuitarString]) -> String {
        (try? String(data: JSONEncoder().encode(strings), encoding: .utf8)) ?? "[]"
    }
}
