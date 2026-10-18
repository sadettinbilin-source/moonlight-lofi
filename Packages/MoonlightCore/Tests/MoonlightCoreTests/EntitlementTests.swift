import XCTest
@testable import MoonlightCore

final class EntitlementTests: XCTestCase {
    func testKnownProductsGrantProUnlessRevoked() {
        for id in ProductIDs.all {
            XCTAssertTrue(EntitlementPolicy.userIsPro(purchases: [ActivePurchase(productID: id, revoked: false)]))
            XCTAssertFalse(EntitlementPolicy.userIsPro(purchases: [ActivePurchase(productID: id, revoked: true)]))
        }
        XCTAssertFalse(EntitlementPolicy.userIsPro(purchases: [ActivePurchase(productID: "com.example.other", revoked: false)]))
        XCTAssertFalse(EntitlementPolicy.userIsPro(purchases: []))
    }

    func testFreePlanLimits() {
        XCTAssertTrue(EntitlementPolicy.canPlay(trackIsPro: false, userIsPro: false))
        XCTAssertFalse(EntitlementPolicy.canPlay(trackIsPro: true, userIsPro: false))
        XCTAssertFalse(EntitlementPolicy.canDownload(userIsPro: false))
        XCTAssertTrue(EntitlementPolicy.canUseScene(sceneIsPro: false, userIsPro: false))
        XCTAssertFalse(EntitlementPolicy.canUseScene(sceneIsPro: true, userIsPro: false))
        XCTAssertFalse(EntitlementPolicy.canViewStats(userIsPro: false))
    }

    func testProPlanUnlocksCatalogDownloadsScenesAndStats() {
        XCTAssertTrue(EntitlementPolicy.canPlay(trackIsPro: true, userIsPro: true))
        XCTAssertTrue(EntitlementPolicy.canPlay(trackIsPro: false, userIsPro: true))
        XCTAssertTrue(EntitlementPolicy.canDownload(userIsPro: true))
        XCTAssertTrue(EntitlementPolicy.canUseScene(sceneIsPro: true, userIsPro: true))
        XCTAssertTrue(EntitlementPolicy.canViewStats(userIsPro: true))
    }

    func testOnlyMoonGardenIsFree() {
        let free = AmbientScene.allCases.filter { !$0.isPro }
        XCTAssertEqual(free, [.moonGarden])
        XCTAssertEqual(AmbientScene.allCases.count, 5)
        XCTAssertFalse(EntitlementPolicy.canUseScene(sceneIsPro: AmbientScene.rainWindow.isPro, userIsPro: false))
        XCTAssertTrue(EntitlementPolicy.canUseScene(sceneIsPro: AmbientScene.moonGarden.isPro, userIsPro: false))
    }
}
