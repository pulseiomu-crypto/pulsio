import CryptoKit
import Foundation
import Security

/// Sign in with Apple replay protection: a random nonce goes to Supabase, its SHA-256 goes on the Apple
/// request, and Apple embeds the hash in the identity token so the server can match them.
struct AppleSignInNonce: Sendable {
    let raw: String
    var hashed: String { Self.sha256(raw) }

    init() {
        raw = Self.randomString(length: 32)
    }

    init(raw: String) {
        self.raw = raw
    }

    static func sha256(_ input: String) -> String {
        SHA256.hash(data: Data(input.utf8)).map { String(format: "%02x", $0) }.joined()
    }

    private static func randomString(length: Int) -> String {
        let charset = Array("0123456789ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz-._")
        var bytes = [UInt8](repeating: 0, count: length)
        let status = SecRandomCopyBytes(kSecRandomDefault, bytes.count, &bytes)
        precondition(status == errSecSuccess, "SecRandomCopyBytes failed: \(status)")
        return String(bytes.map { charset[Int($0) % charset.count] })
    }
}
