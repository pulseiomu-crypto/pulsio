import Foundation
import Supabase

/// The signed-in identity as the rest of the app sees it. Never the SDK's `User`.
struct AuthUser: Equatable, Sendable {
    let id: UUID
    let email: String?
    /// `apple`, `google`, or `email` — which door they came in through.
    let provider: String?
}

enum SessionEvent: Equatable, Sendable {
    case signedIn(AuthUser)
    case signedOut
}

/// Deep-link the auth server redirects back to (magic link, Google OAuth). Registered in Info.plist
/// and must be on the Supabase redirect allow-list.
enum AuthCallback {
    static let scheme = "pulsio"
    static let host = "auth-callback"
    static let url = URL(string: "\(scheme)://\(host)")!

    static func matches(_ url: URL) -> Bool {
        url.scheme?.lowercased() == scheme && url.host()?.lowercased() == host
    }
}

/// Everything the app can do with identity. Three doors — Apple, Google, email magic link — no passwords,
/// so there is deliberately no reset/change-password surface here.
protocol AuthRepository: Sendable {
    /// Emits the current state immediately, then every change. Each call starts a fresh subscription.
    func sessionEvents() -> AsyncStream<SessionEvent>
    func currentUser() -> AuthUser?

    /// Native Sign in with Apple: the identity token from `ASAuthorizationAppleIDCredential` plus the raw
    /// nonce whose SHA-256 was put on the request (Platform/Auth/AppleSignInNonce).
    func signInWithApple(idToken: String, nonce: String) async throws
    /// Google via the system web-auth session (no Google SDK); returns when the callback URL has been handled.
    func signInWithGoogle() async throws
    func sendMagicLink(to email: String) async throws
    /// The 6-digit code from the same email (`{{ .Token }}` in the template). Scanners can't consume a code,
    /// so this is the reliable path when a mail provider pre-opens links.
    func verifyEmailCode(email: String, code: String) async throws
    /// Handle an incoming `pulsio://auth-callback` URL. Returns false if the URL isn't ours.
    func completeSignIn(from url: URL) async throws -> Bool

    /// `everywhere` revokes every session for the account (SPEC §17 "sign out of all devices").
    func signOut(everywhere: Bool) async throws
    /// Server-side `delete_own_account()` — deletes auth.users and everything cascading from it.
    func deleteAccount() async throws
}

struct SupabaseAuthRepository: AuthRepository {
    let gateway: SupabaseGateway

    private var auth: AuthClient { gateway.client.auth }

    func sessionEvents() -> AsyncStream<SessionEvent> {
        let changes = auth.authStateChanges
        return AsyncStream { continuation in
            let task = Task {
                for await (_, session) in changes {
                    continuation.yield(session.map { .signedIn(Self.user(from: $0)) } ?? .signedOut)
                }
                continuation.finish()
            }
            continuation.onTermination = { _ in task.cancel() }
        }
    }

    func currentUser() -> AuthUser? {
        auth.currentSession.map(Self.user(from:))
    }

    func signInWithApple(idToken: String, nonce: String) async throws {
        try await auth.signInWithIdToken(credentials: .init(provider: .apple, idToken: idToken, nonce: nonce))
    }

    func signInWithGoogle() async throws {
        try await auth.signInWithOAuth(provider: .google, redirectTo: AuthCallback.url)
    }

    func sendMagicLink(to email: String) async throws {
        try await auth.signInWithOTP(email: email, redirectTo: AuthCallback.url, shouldCreateUser: true)
    }

    func verifyEmailCode(email: String, code: String) async throws {
        try await auth.verifyOTP(email: email, token: code, type: .email)
    }

    func completeSignIn(from url: URL) async throws -> Bool {
        guard AuthCallback.matches(url) else { return false }
        try await auth.session(from: url)
        return true
    }

    func signOut(everywhere: Bool) async throws {
        try await auth.signOut(scope: everywhere ? .global : .local)
    }

    func deleteAccount() async throws {
        try await gateway.client.rpc("delete_own_account").execute()
        // The server session is gone with the user; clear the local copy regardless of the network result.
        try? await auth.signOut(scope: .local)
    }

    private static func user(from session: Session) -> AuthUser {
        AuthUser(
            id: session.user.id,
            email: session.user.email,
            provider: session.user.appMetadata["provider"]?.stringValue
        )
    }
}
