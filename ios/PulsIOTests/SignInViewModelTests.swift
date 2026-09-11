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

    @Test(arguments: ["123456", "000000", "92947593", "1234567890"])
    func acceptsCodesOfSupabaseLength(s: String) {
        #expect(SignInViewModel.looksLikeCode(s))
    }

    @Test(arguments: ["", "12345", "12345678901", "12345a", "12 345"])
    func rejectsOtherCodes(s: String) {
        #expect(!SignInViewModel.looksLikeCode(s))
    }
}
