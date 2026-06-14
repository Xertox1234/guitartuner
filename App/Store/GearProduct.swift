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
        case priceHint    = "price_hint"
        case sweetwaterUrl = "sweetwater_url"
        case imageUrl     = "image_url"
        case isFeatured   = "is_featured"
        case sortOrder    = "sort_order"
    }

    var affiliateURL: URL? { URL(string: sweetwaterUrl) }
}
