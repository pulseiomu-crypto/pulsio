import Testing
@testable import PulsIO

struct AppleSignInNonceTests {
    @Test func hashesWithSHA256Hex() {
        // Known vector: SHA-256("abc")
        #expect(AppleSignInNonce(raw: "abc").hashed == "ba7816bf8f01cfea414140de5dae2223b00361a396177a9cb410ff61f20015ad")
    }

    @Test func freshNoncesAreUniqueAndLongEnough() {
        let a = AppleSignInNonce(), b = AppleSignInNonce()
        #expect(a.raw != b.raw)
        #expect(a.raw.count == 32)
    }
}
