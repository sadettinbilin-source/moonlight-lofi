import Foundation
import MoonlightCore
import Observation
import StoreKit

@MainActor
@Observable
final class StoreManager {
    private(set) var products: [Product] = []
    private(set) var isPro = false
    private(set) var isLoading = false
    private(set) var purchasingID: String?
    private(set) var errorKey: String?
    private var updates: Task<Void, Never>?

    init() {
        updates = Task { await listenForUpdates() }
        Task { await refresh() }
    }

    func refresh() async {
        isLoading = true
        defer { isLoading = false }
        do {
            let loaded = try await Product.products(for: ProductIDs.all)
            products = ProductIDs.all.compactMap { id in loaded.first { $0.id == id } }
            errorKey = products.isEmpty ? "paywall.unavailable" : nil
            await refreshEntitlements()
        } catch {
            errorKey = "paywall.unavailable"
        }
    }

    func purchase(_ product: Product) async {
        purchasingID = product.id
        errorKey = nil
        defer { purchasingID = nil }
        do {
            let result = try await product.purchase()
            switch result {
            case .success(let verification):
                let transaction = try Self.verified(verification)
                await transaction.finish()
                await refreshEntitlements()
            case .userCancelled, .pending:
                break
            @unknown default:
                break
            }
        } catch {
            errorKey = "paywall.failed"
        }
    }

    func restore() async {
        isLoading = true
        defer { isLoading = false }
        do {
            try await AppStore.sync()
            await refreshEntitlements()
            errorKey = nil
        } catch {
            errorKey = "paywall.failed"
        }
    }

    private func listenForUpdates() async {
        for await result in Transaction.updates {
            guard let transaction = try? Self.verified(result) else { continue }
            await transaction.finish()
            await refreshEntitlements()
        }
    }

    private func refreshEntitlements() async {
        var purchases: [ActivePurchase] = []
        for await result in Transaction.currentEntitlements {
            guard let transaction = try? Self.verified(result) else { continue }
            purchases.append(
                ActivePurchase(
                    productID: transaction.productID,
                    revoked: transaction.revocationDate != nil
                )
            )
        }
        isPro = EntitlementPolicy.userIsPro(purchases: purchases)
    }

    private static func verified<T>(_ result: VerificationResult<T>) throws -> T {
        switch result {
        case .unverified:
            throw StoreError.unverified
        case .verified(let value):
            return value
        }
    }
}

private enum StoreError: Error {
    case unverified
}
