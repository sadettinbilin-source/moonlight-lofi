import XCTest

/// Walks the main screens and keeps a screenshot of each one.
/// The scheme's test action points at Products.storekit, so the paywall can load plans.
final class MoonlightScreenshots: XCTestCase {
    private var app: XCUIApplication!

    override func setUpWithError() throws {
        continueAfterFailure = false
        app = XCUIApplication()
        app.launchArguments = [
            "-AppleLanguages", "(en)",
            "-AppleLocale", "en_US",
            "-UITestDemoPlans"
        ]
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
        let play = requireButton("transport.play", labels: ["Play", "Abspielen"])
        tap(play)
        XCTAssertTrue(waitUntilPlaying(timeout: 20), "Play did not reach the playing state")
        RunLoop.current.run(until: Date().addingTimeInterval(2))
        XCTAssertTrue(isPlaying, "Playback did not stay in the playing state")
        capture("player")
    }

    func testScenes() throws {
        XCTAssertTrue(wait(any("screen.listen"), timeout: 30))
        let garden = sceneButton("moonGarden", labels: ["Moon Garden", "Mondgarten"])
        tap(garden)
        capture("scenes")
    }

    func testLibrary() throws {
        try openTab("tab.library", labels: ["Library", "Bibliothek"])
        XCTAssertTrue(wait(any("screen.library"), timeout: 15))
        capture("library")
    }

    func testFocusTimer() throws {
        try openTab("tab.focus", labels: ["Focus", "Fokus"])
        XCTAssertTrue(wait(any("screen.focus"), timeout: 15))
        _ = requireButton("focus.primary", labels: ["Start focus", "Fokus starten"])
        capture("focus")
    }

    func testSleepTimer() throws {
        XCTAssertTrue(wait(any("screen.listen"), timeout: 30))
        let sleep = requireButton("action.sleep", labels: ["Sleep", "Schlafen"])
        tap(sleep)
        XCTAssertTrue(wait(any("screen.sleep"), timeout: 15))
        capture("sleep")
    }

    func testPaywallLoadsStoreKitPlans() throws {
        try openTab("tab.you", labels: ["You", "Du"])
        let upgrade = requireButton("you.upgrade.plans", labels: ["See Pro plans", "Pro-Pläne ansehen"])
        tap(upgrade)
        XCTAssertTrue(wait(any("screen.paywall"), timeout: 20))
        let planNames = ["Yearly", "Jährlich", "Monthly", "Monatlich"]
        let planID = any("paywall.plan.yearly")
        var appeared = planID.waitForExistence(timeout: 20)
        if !appeared {
            appeared = planNames.contains { app.staticTexts[$0].waitForExistence(timeout: 2) }
        }
        XCTAssertTrue(appeared, "Paywall did not show a yearly or monthly plan.")
        capture("paywall")
    }

    private var isPlaying: Bool {
        let play = app.buttons["transport.play"]
        if play.exists, (play.value as? String) == "playing" { return true }
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

    private func openTab(_ identifier: String, labels: [String]) throws {
        let bar = app.tabBars.firstMatch
        XCTAssertTrue(bar.waitForExistence(timeout: 20), "Tab bar did not appear")
        let byID = bar.buttons[identifier]
        if byID.waitForExistence(timeout: 5) {
            byID.tap()
            return
        }
        for label in labels {
            let byLabel = bar.buttons[label]
            if byLabel.waitForExistence(timeout: 2) {
                byLabel.tap()
                return
            }
        }
        XCTFail("Missing tab \(identifier) / \(labels.joined(separator: ", "))")
    }

    private func sceneButton(_ identifier: String, labels: [String]) -> XCUIElement {
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
        return requireButton("scene.\(identifier)", labels: labels)
    }

    private func requireButton(_ identifier: String, labels: [String], timeout: TimeInterval = 12) -> XCUIElement {
        if let found = button(identifier, labels: labels, timeout: timeout) {
            return found
        }
        XCTFail("Missing button \(identifier) / \(labels.joined(separator: ", "))")
        return app.buttons[identifier]
    }

    private func button(_ identifier: String, labels: [String], timeout: TimeInterval) -> XCUIElement? {
        let byID = app.buttons[identifier]
        if byID.waitForExistence(timeout: timeout) { return byID }
        for label in labels {
            let byLabel = app.buttons[label]
            if byLabel.waitForExistence(timeout: 2) { return byLabel }
        }
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
