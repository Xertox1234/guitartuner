import Foundation
import os

@MainActor @Observable
final class GearStoreModel {
    private static let logger = Logger(subsystem: "com.luma.app", category: "store")
    var products: [GearProduct] = []
    var selectedCategory = "all"
    var isLoading = false
    var fetchError: String?

    private let api: LumaAPI
    private let cacheURL: URL

    init(api: LumaAPI = LumaAPI()) {
        self.api = api
        let support = URL.applicationSupportDirectory
        self.cacheURL = support.appending(component: "luma_gear_products.json")
        self.products = loadCache()
    }

    var featured: GearProduct? { products.first { $0.isFeatured } }

    var filtered: [GearProduct] {
        selectedCategory == "all" ? products : products.filter { $0.category == selectedCategory }
    }

    var categories: [String] {
        var seen = Set<String>()
        return products.compactMap { seen.insert($0.category).inserted ? $0.category : nil }
    }

    func fetch() async {
        isLoading = true
        defer { isLoading = false }
        do {
            let response: ProductsResponse = try await api.get("store/products")
            products = response.products
            persistCache()
        } catch {
            // If cache is non-empty, stay silent — stale products are fine
            if products.isEmpty { fetchError = "Unable to load products" }
        }
    }

    // Defined here because it references GearProduct (not in APIModels.swift)
    private struct ProductsResponse: Decodable { let products: [GearProduct] }

    private func loadCache() -> [GearProduct] {
        guard let data = try? Data(contentsOf: cacheURL) else { return [] }
        return (try? JSONDecoder().decode([GearProduct].self, from: data)) ?? []
    }

    private func persistCache() {
        do {
            try CacheFile.write(products, to: cacheURL)
        } catch {
            // Non-fatal: stale cache on next launch; no user-visible failure.
            Self.logger.error("GearStoreModel: cache write failed — \(String(describing: error), privacy: .private)")
        }
    }
}
