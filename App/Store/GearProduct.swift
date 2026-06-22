import Foundation

struct GearProduct: Identifiable, Codable, Hashable, Sendable {
    let id: String
    let category: String
    let name: String
    let description: String
    let priceHint: String
    let sweetwaterUrl: String
    let imageUrl: String
    let isFeatured: Bool
    let sortOrder: Int

    enum CodingKeys: String, CodingKey {
        case id, category, name, description
        case priceHint     = "price_hint"
        case sweetwaterUrl  = "sweetwater_url"
        case imageUrl      = "image_url"
        case isFeatured    = "is_featured"
        case sortOrder     = "sort_order"
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id            = try c.decode(String.self, forKey: .id)
        category      = try c.decode(String.self, forKey: .category)
        name          = try c.decode(String.self, forKey: .name)
        description   = try c.decodeIfPresent(String.self, forKey: .description) ?? ""
        priceHint     = try c.decodeIfPresent(String.self, forKey: .priceHint) ?? ""
        sweetwaterUrl = try c.decode(String.self, forKey: .sweetwaterUrl)
        imageUrl      = try c.decodeIfPresent(String.self, forKey: .imageUrl) ?? ""
        // D1 INTEGER arrives as a JSON number (1/0). Accept Bool or Int so both
        // the route payload and the locally-cached (Bool-encoded) JSON decode.
        if let b = try? c.decode(Bool.self, forKey: .isFeatured) {
            isFeatured = b
        } else {
            isFeatured = (try c.decode(Int.self, forKey: .isFeatured)) != 0
        }
        sortOrder     = try c.decodeIfPresent(Int.self, forKey: .sortOrder) ?? 0
    }

    var affiliateURL: URL? { URL(string: sweetwaterUrl) }
}
