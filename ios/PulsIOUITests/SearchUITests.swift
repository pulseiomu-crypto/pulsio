import XCTest

/// Search (SPEC §20) against the real on-device POI store: a category query with distances, approximate
/// shelters labelled with tappable numbers, and a tap-through to the map.
final class SearchUITests: XCTestCase {
    private var app: XCUIApplication!

    override func setUp() {
        continueAfterFailure = false
        app = XCUIApplication()
        app.launchEnvironment["MAP_CAMERA"] = "-20.3162,57.5203,12"
        app.launch()
    }

    private func clearField() {
        let field = app.descendants(matching: .any)["search.field"].firstMatch
        field.tap()
        let count = (field.value as? String)?.count ?? 0
        field.typeText(String(repeating: XCUIKeyboardKey.delete.rawValue, count: max(count, 12)))
    }

    private func attach(_ name: String) {
        let a = XCTAttachment(screenshot: app.screenshot())
        a.name = name
        a.lifetime = .keepAlways
        add(a)
    }

    func testPharmacyShelterAndTapThrough() {
        let any = app.descendants(matching: .any)
        XCTAssertTrue(any["map.search"].firstMatch.waitForExistence(timeout: 10))
        any["map.search"].firstMatch.tap()
        let field = any["search.field"].firstMatch
        XCTAssertTrue(field.waitForExistence(timeout: 5))
        field.typeText("pharm")
        let first = any.matching(NSPredicate(format: "identifier BEGINSWITH 'search.result.'")).firstMatch
        XCTAssertTrue(first.waitForExistence(timeout: 10), "pharmacies from the local store")
        XCTAssertTrue(any["search.ordering"].firstMatch.exists)
        attach("search-1-pharmacy")

        // Shelters (typing the category word acts like its chip): approximate ones are labelled, numbers tappable.
        clearField()
        field.typeText("shelter")
        XCTAssertTrue(any["search.approximate"].firstMatch.waitForExistence(timeout: 10), "an approximate shelter is labelled")
        XCTAssertTrue(any.matching(NSPredicate(format: "identifier BEGINSWITH 'search.phone.'")).firstMatch.exists, "tappable numbers")
        attach("search-2-shelters")

        // Back to pharmacies and tap through to the map.
        clearField()
        field.typeText("pharm")
        XCTAssertTrue(first.waitForExistence(timeout: 10))
        first.tap()
        XCTAssertTrue(any["map.callout"].firstMatch.waitForExistence(timeout: 10), "the map opens the result")
        sleep(3)
        attach("search-3-map")
    }
}
