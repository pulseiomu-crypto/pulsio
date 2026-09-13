import XCTest

/// First run: the five steps, the three-priority cap, and landing on the map. Needs a fresh install
/// (`xcrun simctl uninstall` first) — otherwise onboarding is already complete and the test skips.
final class OnboardingTests: XCTestCase {
    private var app: XCUIApplication!

    override func setUp() {
        continueAfterFailure = false
        app = XCUIApplication()
        app.launch()
    }

    private func attach(_ name: String) {
        let a = XCTAttachment(screenshot: app.screenshot())
        a.name = name
        a.lifetime = .keepAlways
        add(a)
    }

    func testFirstRunFlow() throws {
        let next = app.descendants(matching: .any)["onboarding.next"].firstMatch
        guard next.waitForExistence(timeout: 12) else {
            print("TREE:\n\(app.debugDescription)")
            throw XCTSkip("onboarding already completed on this simulator")
        }
        attach("onboarding-1-intro")
        next.tap()                                                   // → What is a Pulse?
        XCTAssertTrue(app.staticTexts["What is a Pulse?"].waitForExistence(timeout: 5))
        attach("onboarding-2-pulse")
        next.tap()                                                   // → What matters to you?
        XCTAssertTrue(app.descendants(matching: .any)["onboarding.type.tourist"].firstMatch.waitForExistence(timeout: 5))
        app.descendants(matching: .any)["onboarding.type.tourist"].firstMatch.tap()
        for p in ["ceb", "weather", "cyclone"] { app.descendants(matching: .any)["onboarding.priority.\(p)"].firstMatch.tap() }
        app.descendants(matching: .any)["onboarding.priority.fuel"].firstMatch.tap()                // 4th: refused by the cap
        XCTAssertEqual(app.staticTexts["onboarding.prefs.count"].label, "3 of 3 selected")
        attach("onboarding-3-preferences")
        next.tap()                                                   // → Why location helps
        XCTAssertTrue(app.staticTexts["Where are you?"].waitForExistence(timeout: 5))
        attach("onboarding-4-location")
        next.tap()                                                   // → The map
        XCTAssertTrue(app.staticTexts["The map"].waitForExistence(timeout: 5))
        attach("onboarding-5-map")
        next.tap()                                                   // → Enter PulsIO
        XCTAssertTrue(app.buttons["pulse.fire"].waitForExistence(timeout: 10), "onboarding should hand over to the map")
        XCTAssertFalse(app.descendants(matching: .any)["onboarding.next"].firstMatch.exists)
        attach("onboarding-6-done")
    }
}
