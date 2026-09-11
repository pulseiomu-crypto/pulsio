import XCTest

/// Drives the sign-in surfaces on a simulator. `MAGIC_LINK_EMAIL` (env) sends a real sign-in link — used
/// for the manual end-to-end check; without it the test stops at the gate.
final class AuthSmokeTests: XCTestCase {
    private var app: XCUIApplication!

    override func setUp() {
        continueAfterFailure = false
        app = XCUIApplication()
        app.launch()
    }

    func testSignedOutProfileButtonOpensGateWithAllThreeDoors() {
        app.buttons["root.account"].tap()
        XCTAssertTrue(app.buttons["signin.apple"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.buttons["signin.google"].exists)
        XCTAssertTrue(app.textFields["signin.email"].exists)
        XCTAssertTrue(app.buttons["signin.sendLink"].exists)
        attachScreenshot(named: "sign-in-gate")
        app.buttons["signin.cancel"].tap()
        XCTAssertTrue(app.buttons["signin.apple"].waitForNonExistence(timeout: 5), "Cancel must return to browsing")
    }

    func testInvalidEmailIsRejectedInline() {
        app.buttons["root.account"].tap()
        let field = app.textFields["signin.email"]
        XCTAssertTrue(field.waitForExistence(timeout: 5))
        field.tap()
        field.typeText("not-an-email")
        app.buttons["signin.sendLink"].tap()
        XCTAssertTrue(app.staticTexts["signin.error"].waitForExistence(timeout: 3))
    }

    func testSendMagicLink() throws {
        guard let email = ProcessInfo.processInfo.environment["MAGIC_LINK_EMAIL"], !email.isEmpty else {
            throw XCTSkip("Set MAGIC_LINK_EMAIL to send a real sign-in link")
        }
        app.buttons["root.account"].tap()
        let field = app.textFields["signin.email"]
        XCTAssertTrue(field.waitForExistence(timeout: 5))
        field.tap()
        field.typeText(email)
        app.buttons["signin.sendLink"].tap()
        XCTAssertTrue(app.staticTexts["signin.linkSent"].waitForExistence(timeout: 15), "expected the 'check your inbox' state")
        attachScreenshot(named: "magic-link-sent")
    }

    /// Run only while signed in (after completing a magic link): opens Account and deletes the account.
    func testDeleteAccount() throws {
        guard ProcessInfo.processInfo.environment["DELETE_ACCOUNT"] == "1" else {
            throw XCTSkip("Set DELETE_ACCOUNT=1 to run against a signed-in simulator")
        }
        app.buttons["root.account"].tap()
        XCTAssertTrue(app.buttons["account.delete"].waitForExistence(timeout: 5), "expected the Account sheet (signed in)")
        app.buttons["account.delete"].tap()
        app.buttons["account.delete.confirm"].tap()
        // Back on the feed, signed out: the profile button now opens the gate.
        XCTAssertTrue(app.buttons["root.account"].waitForExistence(timeout: 10))
        app.buttons["root.account"].tap()
        XCTAssertTrue(app.buttons["signin.apple"].waitForExistence(timeout: 5))
    }

    private func attachScreenshot(named name: String) {
        let attachment = XCTAttachment(screenshot: app.screenshot())
        attachment.name = name
        attachment.lifetime = .keepAlways
        add(attachment)
    }
}
