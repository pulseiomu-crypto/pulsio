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
