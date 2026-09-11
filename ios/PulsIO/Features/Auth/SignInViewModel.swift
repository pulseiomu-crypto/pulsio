import Foundation
import Observation

/// State for the sign-in sheet. Talks to `SessionStore` (the app-level identity), nothing else.
@MainActor
@Observable
final class SignInViewModel {
    enum Phase: Equatable {
        case idle
        case working
        case linkSent(String)
    }

    var email = ""
    var code = ""
    private(set) var phase: Phase = .idle
    private(set) var errorKey: String?

    private let session: SessionStore

    init(session: SessionStore) {
        self.session = session
    }

    var isWorking: Bool { phase == .working }

    func signInWithApple(idToken: String, nonce: String, fullName: String?) async {
        await run { try await session.signInWithApple(idToken: idToken, nonce: nonce, fullName: fullName) }
    }

    func signInWithGoogle() async {
        await run { try await session.signInWithGoogle() }
    }

    func sendMagicLink() async {
        let address = email.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        guard Self.looksLikeEmail(address) else {
            errorKey = "auth.error.invalidEmail"
            return
        }
        await run(success: .linkSent(address)) { try await session.sendMagicLink(to: address) }
    }

    func verifyCode() async {
        guard case .linkSent(let address) = phase else { return }
        let digits = code.filter(\.isNumber)
        guard Self.looksLikeCode(digits) else {
            errorKey = "auth.error.invalidCode"
            return
        }
        // Keep the "sent" state on failure so the user can retry the code or tap the link.
        await run(success: .linkSent(address)) { try await session.verifyEmailCode(email: address, code: digits) }
    }

    func useDifferentEmail() {
        phase = .idle
        code = ""
        errorKey = nil
    }

    nonisolated static func looksLikeCode(_ s: String) -> Bool {
        s.count == 6 && s.allSatisfy(\.isNumber)
    }

    private func run(success: Phase = .idle, _ work: () async throws -> Void) async {
        phase = .working
        errorKey = nil
        do {
            try await work()
            phase = success
        } catch is CancellationError {
            phase = .idle
        } catch {
            // Cancelled system sheets (Apple/Google) are not failures worth a message.
            phase = .idle
            errorKey = Self.isUserCancellation(error) ? nil : "auth.error.generic"
        }
    }

    nonisolated static func looksLikeEmail(_ s: String) -> Bool {
        let parts = s.split(separator: "@", omittingEmptySubsequences: false)
        guard parts.count == 2, !parts[0].isEmpty, parts[1].contains("."), !parts[1].hasPrefix("."), !parts[1].hasSuffix(".") else { return false }
        return !s.contains(where: \.isWhitespace)
    }

    private static func isUserCancellation(_ error: Error) -> Bool {
        let ns = error as NSError
        // ASAuthorizationError.canceled == 1001 (com.apple.AuthenticationServices.AuthorizationError);
        // ASWebAuthenticationSessionError.canceledLogin == 1.
        return (ns.domain == "com.apple.AuthenticationServices.AuthorizationError" && ns.code == 1001)
            || (ns.domain == "com.apple.AuthenticationServices.WebAuthenticationSession" && ns.code == 1)
    }
}
