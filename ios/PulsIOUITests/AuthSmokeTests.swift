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

    /// Settings → Sign in (the gate). Settings itself is never behind the gate.
    private func openGate() {
        app.buttons["root.account"].tap()
        let signIn = app.descendants(matching: .any)["settings.signIn"].firstMatch
        XCTAssertTrue(signIn.waitForExistence(timeout: 5), "signed out: Settings shows a Sign in row")
        signIn.tap()
    }

    /// Settings → Account (signed in).
    private func openAccount() {
        app.buttons["root.account"].tap()
        let account = app.descendants(matching: .any)["settings.account"].firstMatch
        XCTAssertTrue(account.waitForExistence(timeout: 5), "signed in: Settings shows the Account row")
        account.tap()
    }

    /// Close whatever settings/gate sheet is up so the profile button is reachable again.
    private func closeSheets() {
        let done = app.descendants(matching: .any)["settings.done"].firstMatch
        if done.exists { done.tap() }
    }

    func testSignedOutProfileButtonOpensGateWithAllThreeDoors() {
        openGate()
        XCTAssertTrue(app.buttons["signin.apple"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.buttons["signin.google"].exists)
        XCTAssertTrue(app.textFields["signin.email"].exists)
        XCTAssertTrue(app.buttons["signin.sendLink"].exists)
        attachScreenshot(named: "sign-in-gate")
        app.buttons["signin.cancel"].tap()
        XCTAssertTrue(app.buttons["signin.apple"].waitForNonExistence(timeout: 5), "Cancel must return to browsing")
        closeSheets()
    }

    func testInvalidEmailIsRejectedInline() {
        openGate()
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
        openGate()
        let field = app.textFields["signin.email"]
        XCTAssertTrue(field.waitForExistence(timeout: 5))
        field.tap()
        field.typeText(email)
        app.buttons["signin.sendLink"].tap()
        XCTAssertTrue(app.staticTexts["signin.linkSent"].waitForExistence(timeout: 15), "expected the 'check your inbox' state")
        attachScreenshot(named: "magic-link-sent")
    }

    /// Full email door: send the link, then wait for the emailed code to arrive one of two ways — a person
    /// types it into the simulator by hand, or whoever is reading the inbox drops it into `MAGIC_LINK_CODE_FILE`
    /// and the test types it. Ends on the Account sheet.
    func testEmailCodeSignInEndToEnd() throws {
        let env = ProcessInfo.processInfo.environment
        guard let email = env["MAGIC_LINK_EMAIL"], !email.isEmpty, let codeFile = env["MAGIC_LINK_CODE_FILE"] else {
            throw XCTSkip("Set MAGIC_LINK_EMAIL and MAGIC_LINK_CODE_FILE")
        }
        openGate()
        let field = app.textFields["signin.email"]
        XCTAssertTrue(field.waitForExistence(timeout: 5))
        field.tap()
        field.typeText(email)
        app.buttons["signin.sendLink"].tap()
        XCTAssertTrue(app.staticTexts["signin.linkSent"].waitForExistence(timeout: 15))

        let deadline = Date().addingTimeInterval(240)
        var code: String?
        var enteredByHand = false
        while Date() < deadline, code == nil, !enteredByHand {
            if !app.buttons["signin.verifyCode"].exists { enteredByHand = true; break }
            if let raw = try? String(contentsOfFile: codeFile, encoding: .utf8) {
                let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
                if (6...10).contains(trimmed.count), trimmed.allSatisfy(\.isNumber) { code = trimmed }
            }
            if code == nil { sleep(3) }
        }
        if let code {
            let codeField = app.textFields["signin.code"]
            XCTAssertTrue(codeField.waitForExistence(timeout: 5))
            codeField.tap()
            codeField.typeText(code)
            attachScreenshot(named: "code-typed")
            app.buttons["signin.verifyCode"].tap()
            sleep(3)
            attachScreenshot(named: "after-verify-tap")
        } else {
            XCTAssertTrue(enteredByHand, "no code appeared in \(codeFile) within 240s and the gate did not close")
        }

        // Sheet closes on sign-in; the profile button now opens Account.
        XCTAssertTrue(app.buttons["signin.verifyCode"].waitForNonExistence(timeout: 20), "expected the gate to close after a valid code")
        // Settings is still up underneath the closed gate; its first row is now Account.
        let account = app.descendants(matching: .any)["settings.account"].firstMatch
        XCTAssertTrue(account.waitForExistence(timeout: 10), "signed in: Settings shows the Account row"); account.tap()
        XCTAssertTrue(app.staticTexts[email].waitForExistence(timeout: 10), "Account sheet should show the signed-in email")
        XCTAssertTrue(app.buttons["account.delete"].exists)
        attachScreenshot(named: "account-signed-in")
        app.buttons["account.done"].tap()
    }

    /// Google door: taps "Continue with Google", accepts the system web-auth prompt, then waits for a person
    /// to complete Google's sign-in in the simulator. Ends on the Account sheet showing the Google provider.
    func testGoogleSignIn() throws {
        guard ProcessInfo.processInfo.environment["GOOGLE_SIGN_IN"] == "1" else {
            throw XCTSkip("Set GOOGLE_SIGN_IN=1 and complete Google's login by hand in the simulator")
        }
        openGate()
        XCTAssertTrue(app.buttons["signin.google"].waitForExistence(timeout: 5))
        app.buttons["signin.google"].tap()

        // ASWebAuthenticationSession asks "PulsIO wants to use supabase.co to sign in" — a SpringBoard alert.
        let springboard = XCUIApplication(bundleIdentifier: "com.apple.springboard")
        let proceed = springboard.buttons["Continue"]
        if proceed.waitForExistence(timeout: 15) { proceed.tap() }
        sleep(5)
        attachScreen(named: "google-web-auth")

        XCTAssertTrue(app.buttons["signin.google"].waitForNonExistence(timeout: 480), "Google sign-in was not completed in time")
        let account = app.descendants(matching: .any)["settings.account"].firstMatch
        XCTAssertTrue(account.waitForExistence(timeout: 10)); account.tap()
        XCTAssertTrue(app.staticTexts["Signed in with Google"].waitForExistence(timeout: 10), "Account should show the Google provider")
        attachScreenshot(named: "account-google")
        app.buttons["account.done"].tap()
    }

    /// Run only while signed in: Sign out returns the profile button to the gate.
    func testSignOut() throws {
        guard ProcessInfo.processInfo.environment["SIGN_OUT"] == "1" else {
            throw XCTSkip("Set SIGN_OUT=1 to run against a signed-in simulator")
        }
        openAccount()
        XCTAssertTrue(app.buttons["account.signOut"].waitForExistence(timeout: 5), "expected the Account sheet (signed in)")
        app.buttons["account.signOut"].tap()
        XCTAssertTrue(app.buttons["account.signOut"].waitForNonExistence(timeout: 10))
        // Settings is still up underneath; signed out now, its first row is Sign in.
        let signIn = app.descendants(matching: .any)["settings.signIn"].firstMatch
        XCTAssertTrue(signIn.waitForExistence(timeout: 5)); signIn.tap()
        XCTAssertTrue(app.buttons["signin.apple"].waitForExistence(timeout: 5), "signed out: profile button opens the gate")
    }

    /// Run only while signed in: "Sign out of all devices" revokes every session (SPEC §17).
    func testSignOutOfAllDevices() throws {
        guard ProcessInfo.processInfo.environment["SIGN_OUT_ALL"] == "1" else {
            throw XCTSkip("Set SIGN_OUT_ALL=1 to run against a signed-in simulator")
        }
        openAccount()
        XCTAssertTrue(app.buttons["account.signOutAll"].waitForExistence(timeout: 5), "expected the Account sheet (signed in)")
        app.buttons["account.signOutAll"].tap()
        XCTAssertTrue(app.buttons["account.signOutAll"].waitForNonExistence(timeout: 10))
        let signIn = app.descendants(matching: .any)["settings.signIn"].firstMatch
        XCTAssertTrue(signIn.waitForExistence(timeout: 5)); signIn.tap()
        XCTAssertTrue(app.buttons["signin.apple"].waitForExistence(timeout: 5), "signed out: profile button opens the gate")
    }

    /// Run only while signed in (after completing a magic link): opens Account and deletes the account.
    func testDeleteAccount() throws {
        guard ProcessInfo.processInfo.environment["DELETE_ACCOUNT"] == "1" else {
            throw XCTSkip("Set DELETE_ACCOUNT=1 to run against a signed-in simulator")
        }
        openAccount()
        XCTAssertTrue(app.buttons["account.delete"].waitForExistence(timeout: 5), "expected the Account sheet (signed in)")
        XCTAssertTrue(app.buttons["account.signOut"].exists)
        XCTAssertTrue(app.buttons["account.signOutAll"].exists)
        attachScreenshot(named: "account-signed-in")
        app.buttons["account.delete"].tap()
        XCTAssertTrue(app.buttons["account.delete.confirm"].firstMatch.waitForExistence(timeout: 5))
        attachScreenshot(named: "account-delete-confirm")
        app.buttons["account.delete.confirm"].firstMatch.tap()
        // Back on the feed, signed out: the profile button now opens the gate.
        XCTAssertTrue(app.buttons["account.delete"].waitForNonExistence(timeout: 15), "Account sheet should close after deletion")
        let signIn = app.descendants(matching: .any)["settings.signIn"].firstMatch
        XCTAssertTrue(signIn.waitForExistence(timeout: 10), "signed out: Settings now offers Sign in"); signIn.tap()
        XCTAssertTrue(app.buttons["signin.apple"].waitForExistence(timeout: 5))
    }

    /// Whole-screen capture — needed when another process (SpringBoard, the web-auth sheet) is on top.
    private func attachScreen(named name: String) {
        let attachment = XCTAttachment(screenshot: XCUIScreen.main.screenshot())
        attachment.name = name
        attachment.lifetime = .keepAlways
        add(attachment)
    }

    private func attachScreenshot(named name: String) {
        let attachment = XCTAttachment(screenshot: app.screenshot())
        attachment.name = name
        attachment.lifetime = .keepAlways
        add(attachment)
    }
}
