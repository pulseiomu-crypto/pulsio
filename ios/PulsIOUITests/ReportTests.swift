import XCTest

/// Community reports (SPEC §11) on a signed-in simulator. Opt-in via env:
/// - `REPORT_FLOW=1` (+ app env `REPORT_SAMPLE_PHOTO=1`): category → pin → sample photo (blurred on-device) → submit → held/live.
/// - `REPORT_ACTIONS=<id>` (+ app env `OPEN_REPORT_ID`): confirm (2 km check), flag, block on someone else's report.
final class ReportUITests: XCTestCase {
    private func launch(_ env: [String: String] = [:]) -> XCUIApplication {
        let app = XCUIApplication()
        for (k, v) in env { app.launchEnvironment[k] = v }
        app.launch()
        return app
    }

    private func attach(_ app: XCUIApplication, _ name: String) {
        let a = XCTAttachment(screenshot: XCUIScreen.main.screenshot())
        a.name = name
        a.lifetime = .keepAlways
        add(a)
    }

    func testSubmitFlow() throws {
        guard ProcessInfo.processInfo.environment["REPORT_FLOW"] == "1" else { throw XCTSkip("REPORT_FLOW=1 on a signed-in simulator") }
        let app = launch(["REPORT_SAMPLE_PHOTO": "1"])
        let any = app.descendants(matching: .any)
        XCTAssertTrue(any["map.report"].firstMatch.waitForExistence(timeout: 10))
        any["map.report"].firstMatch.tap()
        XCTAssertTrue(any["report.category.flood"].firstMatch.waitForExistence(timeout: 5))
        XCTAssertTrue(any["report.featureNotice"].firstMatch.exists, "the 'may be featured' notice")
        attach(app, "report-1-category")
        any["report.category.flood"].firstMatch.tap()
        XCTAssertTrue(any["report.pin.confirm"].firstMatch.waitForExistence(timeout: 5))
        sleep(2)
        attach(app, "report-2-pin")
        any["report.pin.confirm"].firstMatch.tap()
        XCTAssertTrue(any["report.photo.noPeople"].firstMatch.waitForExistence(timeout: 5), "the 'don't photograph people' line")
        any["report.photo.sample"].firstMatch.tap()
        XCTAssertTrue(any["report.photo.preview"].firstMatch.waitForExistence(timeout: 20), "processed photo preview")
        let line = any["report.photo.processedLine"].firstMatch
        XCTAssertTrue(line.label.contains("text region"), line.label)
        attach(app, "report-3-photo")
        any["report.photo.next"].firstMatch.tap()
        let field = any["report.description"].firstMatch
        XCTAssertTrue(field.waitForExistence(timeout: 5))
        field.tap()
        field.typeText("Royal Road under water outside the school")
        attach(app, "report-4-details")
        any["report.submit"].firstMatch.tap()
        XCTAssertTrue(any["report.done"].firstMatch.waitForExistence(timeout: 30), "submitted")
        attach(app, "report-5-done")
        any["report.done.close"].firstMatch.tap()
    }

    func testCommunityActions() throws {
        guard let id = ProcessInfo.processInfo.environment["REPORT_ACTIONS"] else { throw XCTSkip("REPORT_ACTIONS=<id> on a signed-in simulator") }
        let app = launch(["OPEN_REPORT_ID": id])
        let any = app.descendants(matching: .any)
        XCTAssertTrue(any["reportDetail.confirm"].firstMatch.waitForExistence(timeout: 15), "someone else's live report opens with Confirm")
        attach(app, "report-6-detail")
        any["reportDetail.confirm"].firstMatch.tap()
        let allow = XCUIApplication(bundleIdentifier: "com.apple.springboard").buttons["Allow While Using App"]
        if allow.waitForExistence(timeout: 5) { allow.tap() }
        XCTAssertTrue(app.staticTexts["1 of 2 confirmations"].waitForExistence(timeout: 20), "confirmation recorded")
        attach(app, "report-7-confirmed")
        any["reportDetail.flag"].firstMatch.tap()
        XCTAssertTrue(app.buttons["Spam"].waitForExistence(timeout: 5))
        app.buttons["Spam"].tap()
        sleep(2)
        attach(app, "report-8-flagged")
        any["reportDetail.block"].firstMatch.tap()
        XCTAssertTrue(app.buttons["Block"].waitForExistence(timeout: 5))
        app.buttons["Block"].tap()
        XCTAssertTrue(any["reportDetail.confirm"].firstMatch.waitForNonExistence(timeout: 10), "sheet closes after blocking")
        attach(app, "report-9-blocked")
    }
}
