import MoonlightCore
import StoreKit
import SwiftUI

struct PaywallView: View {
    @Environment(AppModel.self) private var model
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                HStack {
                    Spacer()
                    Button("paywall.close") { dismiss() }
                        .accessibilityIdentifier("paywall.close")
                        .font(.system(.body, design: .rounded))
                        .foregroundStyle(Palette.mist)
                }
                VStack(alignment: .leading, spacing: 6) {
                    Image(systemName: "moon.stars.fill")
                        .font(.title)
                        .foregroundStyle(Palette.moon)
                    Text("paywall.title")
                        .font(.system(size: 34, weight: .medium, design: .rounded))
                        .foregroundStyle(Palette.text)
                    Text("paywall.subtitle")
                        .font(.system(.body, design: .rounded))
                        .foregroundStyle(Palette.muted)
                }
                if model.isPro {
                    Text("paywall.owned")
                        .font(.system(.body, design: .rounded))
                        .foregroundStyle(Palette.moon)
                }
                benefit("paywall.benefit.catalog", "paywall.benefit.catalog.detail")
                benefit("paywall.benefit.downloads", "paywall.benefit.downloads.detail")
                benefit("paywall.benefit.scenes", "paywall.benefit.scenes.detail")
                benefit("paywall.benefit.stats", "paywall.benefit.stats.detail")

                if model.store.isLoading && model.store.products.isEmpty {
                    HStack {
                        ProgressView()
                        Text("paywall.loading")
                    }
                    .font(.system(.subheadline, design: .rounded))
                    .foregroundStyle(Palette.muted)
                } else if model.store.products.isEmpty {
                    Text("paywall.unavailable")
                        .font(.system(.subheadline, design: .rounded))
                        .foregroundStyle(Palette.muted)
                    Button("paywall.retry") {
                        Task { await model.store.refresh() }
                    }
                    .font(.system(.body, design: .rounded))
                    .foregroundStyle(Palette.moon)
                } else if !model.isPro {
                    ForEach(model.store.products, id: \.id) { product in
                        productCard(product)
                    }
                }
                if let errorKey = model.store.errorKey, model.store.products.isEmpty == false {
                    Text(LocalizedStringKey(errorKey))
                        .font(.system(.footnote, design: .rounded))
                        .foregroundStyle(Palette.moon)
                }
                Button("paywall.restore") {
                    Task {
                        await model.restorePurchases()
                        if model.isPro { dismiss() }
                    }
                }
                .font(.system(.body, design: .rounded))
                .foregroundStyle(Palette.mist)
                .frame(maxWidth: .infinity)
                HStack(spacing: 16) {
                    Link("paywall.terms", destination: Links.terms)
                    Link("paywall.privacy", destination: Links.privacy)
                }
                .font(.system(.footnote, design: .rounded))
                .foregroundStyle(Palette.muted)
                .frame(maxWidth: .infinity)
            }
            .padding(24)
        }
        .accessibilityIdentifier("screen.paywall")
    }

    private func benefit(_ title: String, _ detail: String) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(LocalizedStringKey(title))
                .font(.system(.body, design: .rounded).weight(.semibold))
                .foregroundStyle(Palette.text)
            Text(LocalizedStringKey(detail))
                .font(.system(.footnote, design: .rounded))
                .foregroundStyle(Palette.muted)
        }
    }

    private func productCard(_ product: Product) -> some View {
        let featured = product.id == ProductIDs.featured
        return Button {
            Task {
                await model.store.purchase(product)
                model.focus.persist()
                if model.isPro { dismiss() }
            }
        } label: {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    HStack(spacing: 8) {
                        Text(LocalizedStringKey(nameKey(product.id)))
                        if featured {
                            Text("paywall.bestValue")
                                .font(.system(.caption2, design: .rounded).weight(.semibold))
                                .padding(.horizontal, 8)
                                .padding(.vertical, 3)
                                .background(Palette.moon, in: Capsule())
                                .foregroundStyle(Palette.ink)
                        }
                    }
                    Text(LocalizedStringKey(periodKey(product)))
                        .font(.system(.caption, design: .rounded))
                        .foregroundStyle(Palette.muted)
                }
                Spacer()
                if model.store.purchasingID == product.id {
                    ProgressView()
                } else {
                    Text(product.displayPrice)
                        .font(.system(.headline, design: .rounded))
                }
            }
            .font(.system(.body, design: .rounded))
            .foregroundStyle(Palette.text)
            .padding(16)
            .background(
                featured ? Palette.moon.opacity(0.16) : Color.white.opacity(0.05),
                in: RoundedRectangle(cornerRadius: 18, style: .continuous)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .stroke(featured ? Palette.moon : Color.white.opacity(0.1), lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
        .disabled(model.store.purchasingID != nil)
    }

    private func nameKey(_ id: String) -> String {
        switch id {
        case ProductIDs.monthly: return "paywall.monthly"
        case ProductIDs.yearly: return "paywall.yearly"
        case ProductIDs.lifetime: return "paywall.lifetime"
        default: return "paywall.title"
        }
    }

    private func periodKey(_ product: Product) -> String {
        guard let unit = product.subscription?.subscriptionPeriod.unit else {
            return "paywall.period.once"
        }
        switch unit {
        case .month: return "paywall.period.month"
        case .year: return "paywall.period.year"
        default: return "paywall.period.once"
        }
    }
}
