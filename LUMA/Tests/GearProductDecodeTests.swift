import Foundation
import Testing
@testable import LUMA

@Suite("GearProduct decoding (D1 wire format)")
struct GearProductDecodeTests {
    // Mirrors exactly what GET /store/products emits: SELECT * from D1, so
    // is_featured / sort_order are SQLite INTEGER and arrive as JSON NUMBERS
    // (1 / 0), not booleans. This is the previously-untested seam.
    private let payload = """
    {"products":[
      {"id":"prod-snark-st2","category":"tuners","name":"Snark ST-2 Clip-On Tuner","description":"Clip-on chromatic tuner.","price_hint":"~$15","sweetwater_url":"https://www.sweetwater.com/store/search?s=Snark+ST-2","image_url":"","is_featured":1,"sort_order":0},
      {"id":"prod-dunlop-tortex-60","category":"picks","name":"Dunlop Tortex Standard .60mm","description":"Classic .60mm picks.","price_hint":"~$22","sweetwater_url":"https://www.sweetwater.com/store/search?s=Dunlop+Tortex","image_url":"","is_featured":0,"sort_order":8}
    ]}
    """

    // GearStoreModel.ProductsResponse is private; this mirrors its shape.
    private struct Wrapper: Decodable { let products: [GearProduct] }

    @Test func decodesIntegerBackedBooleanAndAllFields() throws {
        let wrapper = try JSONDecoder().decode(Wrapper.self, from: Data(payload.utf8))
        #expect(wrapper.products.count == 2)
        let snark = try #require(wrapper.products.first)
        #expect(snark.id == "prod-snark-st2")
        #expect(snark.isFeatured == true)            // JSON 1 -> Bool true
        #expect(snark.sortOrder == 0)
        #expect(snark.priceHint == "~$15")
        #expect(snark.sweetwaterUrl.contains("sweetwater.com"))
        #expect(wrapper.products[1].isFeatured == false)  // JSON 0 -> Bool false
    }
}
