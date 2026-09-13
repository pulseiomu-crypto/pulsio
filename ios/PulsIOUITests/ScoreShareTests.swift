import XCTest

/// PulsScore (viewable signed-out) and the share sheet with rendered previews.
final class ScoreShareTests: XCTestCase {
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

    func testScoreScreenAndShareSheet() {
        let pill = app.descendants(matching: .any)["map.score"].firstMatch
        XCTAssertTrue(pill.waitForExistence(timeout: 10))
        // Wait for the live score to arrive in the pill before opening.
        wait(for: [expectation(for: NSPredicate(format: "label CONTAINS[c] 'day'"), evaluatedWith: pill)], timeout: 15)
        attach("score-pill")
        pill.tap()
        let verdict = app.staticTexts["pulsscore.verdict"]
        XCTAssertTrue(verdict.waitForExistence(timeout: 10))
        XCTAssertTrue(app.staticTexts["pulsscore.honesty"].waitForExistence(timeout: 5), "the breakdown must say what's measured")
        attach("score-screen")
        app.buttons["pulsscore.share"].tap()
        let preview = app.descendants(matching: .any).matching(NSPredicate(format: "identifier BEGINSWITH 'share.preview.'")).firstMatch
        XCTAssertTrue(preview.waitForExistence(timeout: 15), "a rendered Stories preview")
        XCTAssertTrue(app.buttons["share.send"].exists)
        attach("share-stories")
        app.segmentedControls["share.format"].buttons.element(boundBy: 1).tap()
        XCTAssertTrue(preview.waitForExistence(timeout: 15))
        attach("share-square")
    }
}
