import Foundation

public enum ProductIDs {
    public static let monthly = "com.moonlightlofi.pro.monthly"
    public static let yearly = "com.moonlightlofi.pro.yearly"
    public static let lifetime = "com.moonlightlofi.pro.lifetime"
    public static let all = [monthly, yearly, lifetime]
    public static let featured = yearly

    public static func contains(_ id: String) -> Bool {
        all.contains(id)
    }
}

public struct ActivePurchase: Equatable, Sendable {
    public var productID: String
    public var revoked: Bool

    public init(productID: String, revoked: Bool) {
        self.productID = productID
        self.revoked = revoked
    }
}

/// What Free and Pro may do. StoreKit is intentionally not imported here.
public enum EntitlementPolicy {
    public static func userIsPro(purchases: [ActivePurchase]) -> Bool {
        purchases.contains { ProductIDs.contains($0.productID) && !$0.revoked }
    }

    public static func canPlay(trackIsPro: Bool, userIsPro: Bool) -> Bool {
        !trackIsPro || userIsPro
    }

    public static func canDownload(userIsPro: Bool) -> Bool {
        userIsPro
    }

    public static func canUseScene(sceneIsPro: Bool, userIsPro: Bool) -> Bool {
        !sceneIsPro || userIsPro
    }

    public static func canViewStats(userIsPro: Bool) -> Bool {
        userIsPro
    }
}
