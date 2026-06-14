import SwiftUI

/// Full-screen affiliate store. Products fetched from Cloudflare, tap opens Sweetwater in Safari.
struct GearStoreScreen: View {
    @Bindable var gearStore: GearStoreModel
    @Environment(\.dismiss) private var dismiss
    @Environment(\.openURL) private var openURL

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    categoryPills

                    if let featured = gearStore.featured, gearStore.selectedCategory == "all" {
                        FeaturedBanner(product: featured) { open(featured) }
                    }

                    if gearStore.isLoading && gearStore.products.isEmpty {
                        ProgressView().frame(maxWidth: .infinity).padding(.top, 40)
                    } else if let err = gearStore.fetchError, gearStore.products.isEmpty {
                        ContentUnavailableView(err, systemImage: "bag.badge.questionmark")
                    } else {
                        productGrid
                    }

                    affiliateDisclosure
                }
                .padding(.horizontal, 16)
                .padding(.top, 8)
                .padding(.bottom, 32)
            }
            .navigationTitle("Gear Shop")
#if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
#endif
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Close") { dismiss() }
                }
            }
        }
        .tint(.lumaInTune)
        .task { await gearStore.fetch() }
    }

    // MARK: - Category pills

    private var categoryPills: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                pill("all", label: "All")
                ForEach(gearStore.categories, id: \.self) { cat in
                    pill(cat, label: cat.capitalized)
                }
            }
            .padding(.horizontal, 2)
        }
    }

    private func pill(_ category: String, label: String) -> some View {
        Button {
            gearStore.selectedCategory = category
        } label: {
            Text(label)
                .font(.caption.bold())
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(
                    gearStore.selectedCategory == category ? Color.lumaInTune : Color.secondary.opacity(0.12),
                    in: Capsule()
                )
                .foregroundStyle(gearStore.selectedCategory == category ? Color.black : Color.primary)
        }
    }

    // MARK: - Product grid

    private var productGrid: some View {
        LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
            ForEach(gearStore.filtered) { product in
                ProductCard(product: product) { open(product) }
            }
        }
    }

    private var affiliateDisclosure: some View {
        Text("Affiliate disclosure: LUMA earns a small commission on Sweetwater purchases at no extra cost to you.")
            .font(.caption2)
            .foregroundStyle(.tertiary)
            .multilineTextAlignment(.center)
            .frame(maxWidth: .infinity)
            .padding(.top, 8)
    }

    private func open(_ product: GearProduct) {
        guard let url = product.affiliateURL else { return }
        openURL(url)
    }
}

// MARK: - Sub-views

struct FeaturedBanner: View {
    let product: GearProduct
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 12) {
                RoundedRectangle(cornerRadius: 8)
                    .fill(Color.lumaInTune.opacity(0.15))
                    .frame(width: 56, height: 56)
                    .overlay(Image(systemName: "guitars").font(.title2).foregroundStyle(Color.lumaInTune))

                VStack(alignment: .leading, spacing: 2) {
                    Text("FEATURED")
                        .font(.caption2.bold())
                        .foregroundStyle(Color.lumaInTune)
                        .kerning(1)
                    Text(product.name)
                        .font(.subheadline.bold())
                        .foregroundStyle(.primary)
                    if !product.priceHint.isEmpty {
                        Text(product.priceHint)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
                Spacer()
                Text("View →")
                    .font(.caption.bold())
                    .foregroundStyle(Color.lumaInTune)
            }
            .padding(14)
            .background(Color.lumaInTune.opacity(0.06), in: RoundedRectangle(cornerRadius: 12))
            .overlay(RoundedRectangle(cornerRadius: 12).strokeBorder(Color.lumaInTune.opacity(0.2)))
        }
        .buttonStyle(.plain)
    }
}

struct ProductCard: View {
    let product: GearProduct
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            VStack(alignment: .leading, spacing: 6) {
                RoundedRectangle(cornerRadius: 8)
                    .fill(Color.secondary.opacity(0.08))
                    .frame(height: 60)
                    .overlay(Image(systemName: icon(for: product.category)).font(.title2).foregroundStyle(.secondary))

                Text(product.name)
                    .font(.caption.bold())
                    .foregroundStyle(.primary)
                    .lineLimit(2)
                    .multilineTextAlignment(.leading)

                if !product.priceHint.isEmpty {
                    Text(product.priceHint)
                        .font(.caption2)
                        .foregroundStyle(Color.lumaInTune)
                }

                Text("Shop →")
                    .font(.caption2.bold())
                    .foregroundStyle(Color.lumaInTune)
                    .padding(.horizontal, 8).padding(.vertical, 4)
                    .background(Color.lumaInTune.opacity(0.1), in: RoundedRectangle(cornerRadius: 6))
            }
            .padding(10)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Color.secondary.opacity(0.06), in: RoundedRectangle(cornerRadius: 10))
            .overlay(RoundedRectangle(cornerRadius: 10).strokeBorder(Color.secondary.opacity(0.12)))
        }
        .buttonStyle(.plain)
    }

    private func icon(for category: String) -> String {
        switch category {
        case "strings": return "music.note"
        case "tuners":  return "tuningfork"
        case "guitars": return "guitars"
        case "basses":  return "guitars"
        case "picks":   return "triangle"
        default:        return "bag"
        }
    }
}
