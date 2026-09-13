import XCTest

/// The basemap switcher: satellite and street render with the pins still readable, and the choice persists.
/// Launch with `MAP_CAMERA` over a beach (Flic-en-Flac) so the screenshots show pins on turquoise water.
final class BasemapTests: XCTestCase {
    private func launch() -> XCUIApplication {
        let app = XCUIApplication()
        app.launchEnvironment["MAP_CAMERA"] = "-20.2745,57.3630,14.2"
        app.launch()
        return app
    }

    private func attach(_ app: XCUIApplication, _ name: String) {
        let a = XCTAttachment(screenshot: app.screenshot())
        a.name = name
        a.lifetime = .keepAlways
        add(a)
    }

    func testSwitchesAndPersists() {
        continueAfterFailure = false
        var app = launch()
        let satellite = app.descendants(matching: .any)["map.basemap.satellite"].firstMatch
        XCTAssertTrue(satellite.waitForExistence(timeout: 10))
        sleep(4)
        attach(app, "basemap-dark-beach")
        satellite.tap()
        sleep(6)   // imagery tiles
        XCTAssertEqual(satellite.value as? String, "on")
        attach(app, "basemap-satellite-beach")
        app.descendants(matching: .any)["map.basemap.street"].firstMatch.tap()
        sleep(5)
        attach(app, "basemap-street-beach")
        app.descendants(matching: .any)["map.basemap.satellite"].firstMatch.tap()
        sleep(2)

        app.terminate()
        app = launch()
        let again = app.descendants(matching: .any)["map.basemap.satellite"].firstMatch
        XCTAssertTrue(again.waitForExistence(timeout: 10))
        XCTAssertEqual(again.value as? String, "on", "basemap choice should persist between sessions")
        sleep(5)
        attach(app, "basemap-satellite-relaunch")
        app.descendants(matching: .any)["map.basemap.dark"].firstMatch.tap()   // leave the simulator on the default
    }
}
