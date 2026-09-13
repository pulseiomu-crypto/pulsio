import XCTest

/// The map on a simulator: pins from the on-device store, the fuel layer toggle, a pin callout, and the
/// ODbL attribution that must always be visible.
final class MapSmokeTests: XCTestCase {
    private var app: XCUIApplication!

    override func setUp() {
        continueAfterFailure = false
        app = XCUIApplication()
        app.launch()
    }

    func testMapShowsPlacesAttributionAndFuelToggle() {
        let attribution = app.staticTexts["map.attribution"]
        XCTAssertTrue(attribution.waitForExistence(timeout: 10))
        XCTAssertTrue(attribution.label.contains("© OpenStreetMap contributors"), "ODbL attribution must be visible")

        // Sync finishes → "N places" (N > 0) replaces the syncing line.
        let places = app.staticTexts.matching(NSPredicate(format: "label MATCHES %@", #"^\d+ places$"#)).firstMatch
        XCTAssertTrue(places.waitForExistence(timeout: 30), "expected the plotted count after sync")
        let before = Int(places.label.split(separator: " ")[0]) ?? 0
        XCTAssertGreaterThan(before, 50, "expected the SPEC §20 pin set to be plotted")
        attach("map-pins")

        app.buttons["map.layer.fuel"].tap()
        let more = app.staticTexts.matching(NSPredicate(format: "label MATCHES %@", #"^\d+ places$"#)).firstMatch
        let grew = NSPredicate { _, _ in (Int(more.label.split(separator: " ")[0]) ?? 0) > before }
        let exp = expectation(for: grew, evaluatedWith: nil)
        wait(for: [exp], timeout: 10)
        attach("map-fuel-on")
        app.buttons["map.layer.fuel"].tap()
    }

    private func attach(_ name: String) {
        let a = XCTAttachment(screenshot: app.screenshot())
        a.name = name
        a.lifetime = .keepAlways
        add(a)
    }
}

/// The location layer (SPEC §10). Opt-in: `LOCATION_FLOW=allow` expects a simulated location set on the
/// simulator and answers the system prompt with Allow; `LOCATION_FLOW=deny` declines and expects the picker.
final class LocationFlowTests: XCTestCase {
    private var app: XCUIApplication!

    override func setUp() {
        continueAfterFailure = false
        app = XCUIApplication()
        app.launch()
    }

    private func attach(_ name: String) {
        let a = XCTAttachment(screenshot: XCUIScreen.main.screenshot())
        a.name = name
        a.lifetime = .keepAlways
        add(a)
    }

    private func openPrimerAndAllowTapped() {
        XCTAssertTrue(app.buttons["map.locate"].waitForExistence(timeout: 10))
        app.buttons["map.locate"].tap()
        XCTAssertTrue(app.buttons["location.allow"].waitForExistence(timeout: 5), "in-context primer before the system prompt")
        attach("location-primer")
        app.buttons["location.allow"].tap()
    }

    func testAllowResolvesDistrictOnDevice() throws {
        guard ProcessInfo.processInfo.environment["LOCATION_FLOW"] == "allow" else { throw XCTSkip("LOCATION_FLOW=allow") }
        openPrimerAndAllowTapped()
        let springboard = XCUIApplication(bundleIdentifier: "com.apple.springboard")
        let allow = springboard.buttons["Allow While Using App"]
        XCTAssertTrue(allow.waitForExistence(timeout: 10), "system prompt")
        allow.tap()
        let chip = app.buttons["map.district"]
        let resolved = NSPredicate(format: "label CONTAINS[c] 'Plaines Wilhems'")
        wait(for: [expectation(for: resolved, evaluatedWith: chip)], timeout: 30)
        XCTAssertTrue(chip.label.localizedCaseInsensitiveContains("From your location"))
        sleep(3)   // let the blue dot land
        attach("location-allowed")
    }

    func testDenyFallsBackToPickerWithHonestFraming() throws {
        guard ProcessInfo.processInfo.environment["LOCATION_FLOW"] == "deny" else { throw XCTSkip("LOCATION_FLOW=deny") }
        openPrimerAndAllowTapped()
        let springboard = XCUIApplication(bundleIdentifier: "com.apple.springboard")
        let deny = springboard.buttons["Don’t Allow"]
        XCTAssertTrue(deny.waitForExistence(timeout: 10), "system prompt")
        deny.tap()
        let framing = app.staticTexts["district.framing"]
        XCTAssertTrue(framing.waitForExistence(timeout: 10), "picker after decline")
        XCTAssertEqual(framing.label, "PulsIO works best when it knows where you are. Without it, pick your district and we'll show alerts and conditions for that area.")
        attach("location-declined-picker")
        app.buttons["district.option.Flacq"].tap()
        let chip = app.buttons["map.district"]
        let picked = NSPredicate(format: "label CONTAINS[c] 'Flacq'")
        wait(for: [expectation(for: picked, evaluatedWith: chip)], timeout: 10)
        XCTAssertTrue(chip.label.localizedCaseInsensitiveContains("Chosen by you"))
        attach("location-manual")
    }
}

/// The pulse mechanic against the live rules. Opt-in (`PULSE_FLOW=1`) and expects a signed-in free-tier
/// simulator with today's pulse unused: fires once (ceremony runs), lands in the spent state with the
/// midnight countdown, and the next tap opens the P-103 sheet.
final class PulseFlowTests: XCTestCase {
    private var app: XCUIApplication!

    override func setUp() {
        continueAfterFailure = false
        app = XCUIApplication()
        app.launch()
    }

    private func attach(_ name: String) {
        let a = XCTAttachment(screenshot: XCUIScreen.main.screenshot())
        a.name = name
        a.lifetime = .keepAlways
        add(a)
    }

    func testFreeTierFiresOnceThenIsSpent() throws {
        guard ProcessInfo.processInfo.environment["PULSE_FLOW"] == "1" else { throw XCTSkip("PULSE_FLOW=1 on a signed-in simulator") }
        let state = app.staticTexts["pulse.state"]
        XCTAssertTrue(state.waitForExistence(timeout: 10))
        let available = NSPredicate(format: "label CONTAINS[c] 'available'")
        wait(for: [expectation(for: available, evaluatedWith: state)], timeout: 15)
        XCTAssertTrue(state.label.contains("1"), "free tier starts the day with 1: \(state.label)")
        attach("pulse-available")

        app.buttons["pulse.fire"].tap()
        let firing = NSPredicate(format: "label CONTAINS[c] 'firing'")
        wait(for: [expectation(for: firing, evaluatedWith: state)], timeout: 10)
        sleep(4)
        attach("pulse-ceremony")
        let spent = NSPredicate(format: "label CONTAINS[c] 'spent' AND label CONTAINS[c] 'next'")
        wait(for: [expectation(for: spent, evaluatedWith: state)], timeout: 20)
        attach("pulse-spent")

        app.buttons["pulse.fire"].tap()
        XCTAssertTrue(app.staticTexts["pulse.spent.code"].waitForExistence(timeout: 5))
        XCTAssertEqual(app.staticTexts["pulse.spent.code"].label, "P-103")
        attach("pulse-spent-sheet")
    }

    /// The payoff: after the ceremony the result panel opens at half height with the server-ordered rows.
    /// `PANEL_FIRST_ROW` (optional) asserts which row the server put first — set priorities on the profile to check reordering.
    func testPanelOpensAfterPulse() throws {
        guard ProcessInfo.processInfo.environment["PANEL_FLOW"] == "1" else { throw XCTSkip("PANEL_FLOW=1 on a signed-in, unspent simulator") }
        let state = app.staticTexts["pulse.state"]
        XCTAssertTrue(state.waitForExistence(timeout: 10))
        wait(for: [expectation(for: NSPredicate(format: "label CONTAINS[c] 'available'"), evaluatedWith: state)], timeout: 15)
        app.buttons["pulse.fire"].tap()

        let header = app.descendants(matching: .any)["panel.header"].firstMatch
        XCTAssertTrue(header.waitForExistence(timeout: 30), "panel should open after the ceremony")
        sleep(1)
        attach("panel-half")
        for key in ["cyclone", "ceb", "temperature", "humidity", "wind", "uv", "score", "fuel", "events", "sunset"] {
            XCTAssertTrue(app.descendants(matching: .any)["panel.row.\(key)"].firstMatch.exists, "row \(key) missing")
        }
        if let first = ProcessInfo.processInfo.environment["PANEL_FIRST_ROW"] {
            let firstRow = app.descendants(matching: .any).matching(NSPredicate(format: "identifier BEGINSWITH 'panel.row.'")).firstMatch
            XCTAssertEqual(firstRow.identifier, "panel.row.\(first)")
        }
        // Drag to full for the complete list, then screenshot.
        app.swipeUp()
        sleep(1)
        attach("panel-full")
        // Tapping a map row steps the panel aside; the reopen chip brings it back.
        app.descendants(matching: .any)["panel.row.ceb"].firstMatch.tap()
        XCTAssertTrue(app.buttons["panel.reopen"].waitForExistence(timeout: 5))
        attach("panel-dismissed")
        app.buttons["panel.reopen"].tap()
        XCTAssertTrue(header.waitForExistence(timeout: 5))
    }
}
