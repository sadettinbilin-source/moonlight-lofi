import XCTest

/// Walks the main screens and keeps a screenshot of each one.
/// The scheme's test action points at Products.storekit, so the paywall can load plans.
final class MoonlightScreenshots: XCTestCase {
    private var app: XCUIApplication!

    override func setUpWithError() throws {
        continueAfterFailure = false
        app = XCUIApplication()
        app.launchArguments = ["-AppleLanguages", "(en)", "-AppleLocale", "en_US"]
        addUIInterruptionMonitor(withDescription: "System dialog") { alert in
            for label in ["Allow", "Don’t Allow", "Don't Allow", "OK", "Not Now", "Close"] {
                let button = alert.buttons[label]
                if button.exists {
                    button.tap()
                    return true
                }
            }
            return false
        }
        app.launch()
    }

    override func tearDownWithError() throws {
        app?.terminate()
        app = nil
    }

    func testPlayerPlaysAFreeTrack() throws {
        XCTAssertTrue(wait(any("screen.listen"), timeout: 30))
        let play = requireButton("transport.play", label: "Play")
        tap(play)
        XCTAssertTrue(waitUntilPlaying(timeout: 20), "Play did not reach the playing state")
        RunLoop.current.run(until: Date().addingTimeInterval(2))
        XCTAssertTrue(isPlaying, "Playback did not stay in the playing state")
        capture("player")
    }

    func testScenes() throws {
        XCTAssertTrue(wait(any("screen.listen"), timeout: 30))
        let garden = sceneButton("moonGarden", label: "Moon Garden")
        tap(garden)
        capture("scenes")
    }

    func testLibrary() throws {
        try openTab("tab.library", label: "Library")
        XCTAssertTrue(wait(any("screen.library"), timeout: 15))
        capture("library")
    }

    func testFocusTimer() throws {
        try openTab("tab.focus", label: "Focus")
        XCTAssertTrue(wait(any("screen.focus"), timeout: 15))
        _ = requireButton("focus.primary", label: "Start focus")
        capture("focus")
    }

    func testSleepTimer() throws {
        XCTAssertTrue(wait(any("screen.listen"), timeout: 30))
        let sleep = requireButton("action.sleep", label: "Sleep")
        tap(sleep)
        XCTAssertTrue(wait(any("screen.sleep"), timeout: 15))
        capture("sleep")
    }

    func testPaywallLoadsStoreKitPlans() throws {
        try openTab("tab.you", label: "You")
        let upgrade = requireButton("you.upgrade", label: "See Pro plans")
        tap(upgrade)
        XCTAssertTrue(wait(any("screen.paywall"), timeout: 20))
        let yearly = app.staticTexts["Yearly"]
        let monthly = app.staticTexts["Monthly"]
        let appeared = yearly.waitForExistence(timeout: 40) || monthly.waitForExistence(timeout: 5)
        XCTAssertTrue(appeared, "StoreKit configuration did not load a plan. Check the scheme test action.")
        capture("paywall")
    }

    private var isPlaying: Bool {
        let play = app.buttons["transport.play"]
        if (play.value as? String) == "playing" { return true }
        return app.buttons["Pause"].exists
    }

    private func waitUntilPlaying(timeout: TimeInterval) -> Bool {
        let deadline = Date().addingTimeInterval(timeout)
        while Date() < deadline {
            if isPlaying { return true }
            RunLoop.current.run(until: Date().addingTimeInterval(0.25))
        }
        return isPlaying
    }

    private func openTab(_ identifier: String, label: String) throws {
        let bar = app.tabBars.firstMatch
        XCTAssertTrue(bar.waitForExistence(timeout: 20), "Tab bar did not appear")
        let byID = bar.buttons[identifier]
        if byID.waitForExistence(timeout: 5) {
            byID.tap()
            return
        }
        let byLabel = bar.buttons[label]
        XCTAssertTrue(byLabel.waitForExistence(timeout: 8), "Missing tab \(identifier) / \(label)")
        byLabel.tap()
    }

    private func sceneButton(_ identifier: String, label: String) -> XCUIElement {
        let picker = app.scrollViews["scene.picker"]
        let scoped = picker.buttons["scene.\(identifier)"]
        if picker.waitForExistence(timeout: 8) {
            var attempts = 0
            while !scoped.exists && attempts < 5 {
                picker.swipeLeft()
                attempts += 1
            }
            if scoped.exists {
                var swipes = 0
                while !scoped.isHittable && swipes < 5 {
                    picker.swipeLeft()
                    swipes += 1
                }
                return scoped
            }
        }
        return requireButton("scene.\(identifier)", label: label)
    }

    private func requireButton(_ identifier: String, label: String, timeout: TimeInterval = 12) -> XCUIElement {
        if let found = button(identifier, label: label, timeout: timeout) {
            return found
        }
        XCTFail("Missing button \(identifier) / \(label)")
        return app.buttons[identifier]
    }

    private func button(_ identifier: String, label: String, timeout: TimeInterval) -> XCUIElement? {
        let byID = app.buttons[identifier]
        if byID.waitForExistence(timeout: timeout) { return byID }
        let byLabel = app.buttons[label]
        if byLabel.waitForExistence(timeout: 4) { return byLabel }
        return nil
    }

    private func any(_ identifier: String) -> XCUIElement {
        app.descendants(matching: .any)[identifier]
    }

    @discardableResult
    private func wait(_ element: XCUIElement, timeout: TimeInterval = 12) -> Bool {
        element.waitForExistence(timeout: timeout)
    }

    private func tap(_ element: XCUIElement) {
        if !element.isHittable {
            app.swipeUp()
        }
        if element.isHittable {
            element.tap()
        } else {
            element.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5)).tap()
        }
    }

    private func capture(_ name: String) {
        let attachment = XCTAttachment(screenshot: XCUIScreen.main.screenshot())
        attachment.name = name
        attachment.lifetime = .keepAlways
        add(attachment)
    }
}
