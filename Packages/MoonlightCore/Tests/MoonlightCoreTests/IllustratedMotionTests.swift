import XCTest
@testable import MoonlightCore

final class IllustratedMotionTests: XCTestCase {
    private let portrait = (width: 390.0, height: 844.0)

    func testFreeScenesAreLunaStudyAndMoonGarden() {
        let free = AmbientScene.allCases.filter { !$0.isPro }
        XCTAssertEqual(free, [.lunaStudy, .moonGarden])
        XCTAssertEqual(AmbientScene.allCases.count, 8)
        XCTAssertEqual(AmbientScene.defaultScene, .lunaStudy)
        XCTAssertTrue(AmbientScene.lunaSleep.isPro)
        XCTAssertTrue(AmbientScene.lunaRooftop.isPro)
        XCTAssertTrue(EntitlementPolicy.canUseScene(sceneIsPro: AmbientScene.lunaStudy.isPro, userIsPro: false))
        XCTAssertFalse(EntitlementPolicy.canUseScene(sceneIsPro: AmbientScene.lunaSleep.isPro, userIsPro: false))
        XCTAssertTrue(EntitlementPolicy.canUseScene(sceneIsPro: AmbientScene.lunaRooftop.isPro, userIsPro: true))
    }

    func testIllustratedScenesPointAtTheBundledPaintings() {
        XCTAssertEqual(AmbientScene.lunaStudy.imageName, "luna_focus")
        XCTAssertEqual(AmbientScene.lunaSleep.imageName, "luna_sleep")
        XCTAssertEqual(AmbientScene.lunaRooftop.imageName, "luna_rooftop")
        XCTAssertNil(AmbientScene.moonGarden.imageName)
        XCTAssertTrue(AmbientScene.lunaStudy.focalPoint.x > 0.5)
        XCTAssertTrue(AmbientScene.lunaSleep.focalPoint.x > 0.5)
        XCTAssertGreaterThan(AmbientScene.lunaRooftop.focalPoint.x, AmbientScene.lunaStudy.focalPoint.x)

        let root = RepoPaths.root.appendingPathComponent("MoonlightLofi/Resources/Assets.xcassets")
        for scene in AmbientScene.allCases where scene.isIllustrated {
            let name = try! XCTUnwrap(scene.imageName)
            let folder = root.appendingPathComponent("\(name).imageset")
            XCTAssertTrue(FileManager.default.fileExists(atPath: folder.appendingPathComponent("\(name).jpg").path))
            let contents = try! String(contentsOf: folder.appendingPathComponent("Contents.json"), encoding: .utf8)
            XCTAssertTrue(contents.contains("\(name).jpg"))
        }
    }

    func testSleepTimerOffersLunaSleepUntilDismissedOrSelected() {
        XCTAssertEqual(SleepSceneOffer.scene, .lunaSleep)
        XCTAssertFalse(SleepSceneOffer.shouldOffer(sleepTimerActive: false, selected: .lunaStudy, dismissed: false))
        XCTAssertTrue(SleepSceneOffer.shouldOffer(sleepTimerActive: true, selected: .lunaStudy, dismissed: false))
        XCTAssertTrue(SleepSceneOffer.shouldOffer(sleepTimerActive: true, selected: .moonGarden, dismissed: false))
        XCTAssertFalse(SleepSceneOffer.shouldOffer(sleepTimerActive: true, selected: .lunaSleep, dismissed: false))
        XCTAssertFalse(SleepSceneOffer.shouldOffer(sleepTimerActive: true, selected: .lunaRooftop, dismissed: true))
    }

    func testStillCropIgnoresTimeAndStaysInsideTheScaleRange() {
        let still = place(time: 0, animated: false)
        let later = place(time: 80, animated: false)
        XCTAssertEqual(still, later)
        XCTAssertEqual(still.scale, IllustratedMotion.minimumScale, accuracy: 0.0001)
        XCTAssertTrue(still.covers(viewWidth: portrait.width, viewHeight: portrait.height))
    }

    func testKenBurnsStaysSlowAndKeepsLunaInFrame() {
        let start = place(time: 0, animated: true)
        let quarter = place(time: IllustratedMotion.cycle / 4, animated: true)
        XCTAssertGreaterThanOrEqual(start.scale, IllustratedMotion.minimumScale - 0.0001)
        XCTAssertLessThanOrEqual(start.scale, IllustratedMotion.maximumScale + 0.0001)
        XCTAssertGreaterThanOrEqual(quarter.scale, IllustratedMotion.minimumScale - 0.0001)
        XCTAssertLessThanOrEqual(quarter.scale, IllustratedMotion.maximumScale + 0.0001)
        XCTAssertTrue(start.covers(viewWidth: portrait.width, viewHeight: portrait.height))
        XCTAssertTrue(quarter.covers(viewWidth: portrait.width, viewHeight: portrait.height))

        let shift = abs(start.originX - quarter.originX)
        XCTAssertGreaterThan(shift, 0.5)
        XCTAssertLessThan(shift, portrait.width * 0.08)

        let focalX = quarter.originX + AmbientScene.lunaRooftop.focalPoint.x * quarter.width
        XCTAssertEqual(focalX, portrait.width * 0.5, accuracy: portrait.width * 0.06)
    }

    func testCropCoversLandscapeAndSquareViews() {
        let sizes = [(1366.0, 1024.0), (768.0, 1024.0), (600.0, 600.0)]
        for (width, height) in sizes {
            let placement = IllustratedMotion.placement(
                imageAspect: AmbientScene.lunaStudy.artworkAspect!,
                viewWidth: width,
                viewHeight: height,
                focal: AmbientScene.lunaStudy.focalPoint,
                time: 12,
                animated: true
            )
            XCTAssertTrue(placement.covers(viewWidth: width, viewHeight: height))
        }
    }

    func testSceneTitlesBreakOnSpacesOnly() {
        XCTAssertEqual(SceneTitleLayout.lines(for: "Sternenufer"), ["Sternenufer"])
        XCTAssertEqual(SceneTitleLayout.lines(for: "scene.lunaStudy"), ["scene.lunaStudy"])
        XCTAssertEqual(SceneTitleLayout.lines(for: "Luna Study"), ["Luna", "Study"])
        XCTAssertEqual(SceneTitleLayout.lines(for: "Starlit Shore"), ["Starlit", "Shore"])
        XCTAssertEqual(SceneTitleLayout.lines(for: "Luna auf dem Dach"), ["Luna auf", "dem Dach"])
        for line in SceneTitleLayout.lines(for: "Luna auf dem Dach") {
            XCTAssertFalse(line.contains("\n"))
            XCTAssertFalse(line.hasPrefix(" "))
            XCTAssertFalse(line.hasSuffix(" "))
        }
    }

    private func place(time: TimeInterval, animated: Bool) -> ImagePlacement {
        IllustratedMotion.placement(
            imageAspect: AmbientScene.lunaRooftop.artworkAspect!,
            viewWidth: portrait.width,
            viewHeight: portrait.height,
            focal: AmbientScene.lunaRooftop.focalPoint,
            time: time,
            animated: animated
        )
    }
}
