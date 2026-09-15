import XCTest

/// Settings is reachable signed-out; district and preferences are editable there; only Account needs sign-in.
final class SettingsUITests: XCTestCase {
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

    func testSignedOutSettingsAreUsable() {
        let any = app.descendants(matching: .any)
        XCTAssertTrue(app.buttons["root.account"].waitForExistence(timeout: 10))
        app.buttons["root.account"].tap()
        XCTAssertTrue(any["settings.signIn"].firstMatch.waitForExistence(timeout: 5), "signed out: a Sign in row, not a wall")
        XCTAssertTrue(any["settings.district"].firstMatch.exists)
        attach("settings-1-top")

        // Priorities are editable here, with the same cap as onboarding.
        let count = any["settings.prefs.count"].firstMatch
        app.swipeUp()
        // Whatever state the device is in, the first chip toggles: on→off always changes the count; off→on
        // changes it unless the cap (3) is full, in which case a second tap on a selected chip must.
        let before = count.label
        let changed = NSPredicate(format: "label != %@", before)
        any["settings.priority.ceb"].firstMatch.tap()
        if XCTWaiter().wait(for: [expectation(for: changed, evaluatedWith: count)], timeout: 3) != .completed {
            XCTAssertTrue(before.hasPrefix("3 of 3"), "count unchanged only when at the cap: \(before)")
            any["settings.priority.weather"].firstMatch.tap()   // one of the three; toggles off
            wait(for: [expectation(for: changed, evaluatedWith: count)], timeout: 3)
        }
        attach("settings-2-preferences")

        // District picker opens from here.
        app.swipeDown()
        any["settings.district"].firstMatch.tap()
        XCTAssertTrue(any["district.option.Moka"].firstMatch.waitForExistence(timeout: 5))
        any["district.option.Moka"].firstMatch.tap()
        XCTAssertTrue(any["settings.district"].firstMatch.waitForExistence(timeout: 5))
        XCTAssertTrue(any["settings.district"].firstMatch.label.contains("Moka"))

        // Plans sheet (tier rules from the server) and About.
        app.swipeUp()
        any["settings.upgrade"].firstMatch.tap()
        XCTAssertTrue(any["upgrade.tier.t1"].firstMatch.waitForExistence(timeout: 10), "tier rules loaded from pulsio_tier_rules")
        attach("settings-3-plans")
        app.buttons["Done"].firstMatch.tap()
        app.swipeUp(); app.swipeUp()
        XCTAssertTrue(any["settings.attribution"].firstMatch.waitForExistence(timeout: 5), "ODbL attribution in About")
        XCTAssertTrue(any["settings.version"].firstMatch.exists)
        attach("settings-4-about")
        any["settings.done"].firstMatch.tap()
    }
}
