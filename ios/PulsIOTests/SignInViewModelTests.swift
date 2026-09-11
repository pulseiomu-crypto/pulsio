import Testing
@testable import PulsIO

struct SignInViewModelTests {
    @Test(arguments: ["meg@pulsio.mu", "a.b+tag@example.co.uk"])
    func acceptsPlausibleEmails(s: String) {
        #expect(SignInViewModel.looksLikeEmail(s))
    }

    @Test(arguments: ["", "meg", "meg@", "@pulsio.mu", "meg@pulsio", "meg @pulsio.mu", "meg@.mu", "meg@pulsio."])
    func rejectsImplausibleEmails(s: String) {
        #expect(!SignInViewModel.looksLikeEmail(s))
    }

    @Test(arguments: ["123456", "000000"])
    func acceptsSixDigitCodes(s: String) {
        #expect(SignInViewModel.looksLikeCode(s))
    }

    @Test(arguments: ["", "12345", "1234567", "12345a", "12 345"])
    func rejectsNonSixDigitCodes(s: String) {
        #expect(!SignInViewModel.looksLikeCode(s))
    }
}
