import Foundation
import Observation

/// App-level identity state (ARCHITECTURE §4: session is one of the few genuinely global things).
/// Owns the auth subscription, the user's profile, and the emergency flag; injected through the environment.
@MainActor
@Observable
final class SessionStore {
    enum State: Equatable {
        case restoring
        case signedOut
        case signedIn(AuthUser)
    }

    private(set) var state: State = .restoring
    private(set) var profile: Profile?
    private(set) var emergency: EmergencyState = .none
    /// Last non-fatal failure (profile load, emergency fetch), for surfaces that want to show it.
    private(set) var lastError: String?

    private let auth: any AuthRepository
    private let profiles: any ProfileRepository
    private let emergencies: any EmergencyRepository
    private var listener: Task<Void, Never>?
    /// Set once by Apple's credential (Apple only sends the name on the very first authorisation).
    private var pendingDisplayName: String?

    init(auth: any AuthRepository, profiles: any ProfileRepository, emergencies: any EmergencyRepository) {
        self.auth = auth
        self.profiles = profiles
        self.emergencies = emergencies
    }

    var user: AuthUser? {
        if case .signedIn(let user) = state { return user }
        return nil
    }

    var isSignedIn: Bool { user != nil }

    // MARK: Lifecycle

    /// Start listening for auth changes and refresh the emergency flag. Idempotent.
    func start() {
        guard listener == nil else { return }
        listener = Task { [weak self] in
            guard let self else { return }
            for await event in auth.sessionEvents() {
                await apply(event)
            }
        }
        Task { await refreshEmergency() }
    }

    func refreshEmergency() async {
        do {
            emergency = try await emergencies.current()
        } catch {
            // Fail closed: no emergency exception unless the server says so.
            lastError = String(describing: error)
        }
    }

    private func apply(_ event: SessionEvent) async {
        switch event {
        case .signedOut:
            state = .signedOut
            profile = nil
        case .signedIn(let user):
            let alreadySignedIn = (self.user == user)
            state = .signedIn(user)
            if !alreadySignedIn || profile == nil {
                await loadProfile(for: user)
            }
        }
    }

    private func loadProfile(for user: AuthUser) async {
        do {
            var loaded = try await profiles.ensureProfile(for: user.id)
            if loaded.displayName == nil, let name = pendingDisplayName {
                loaded = try await profiles.updateDisplayName(name, for: user.id)
            }
            pendingDisplayName = nil
            profile = loaded
        } catch {
            lastError = String(describing: error)
        }
    }

    // MARK: Sign in

    func signInWithApple(idToken: String, nonce: String, fullName: String?) async throws {
        pendingDisplayName = fullName
        try await auth.signInWithApple(idToken: idToken, nonce: nonce)
    }

    func signInWithGoogle() async throws {
        try await auth.signInWithGoogle()
    }

    func sendMagicLink(to email: String) async throws {
        try await auth.sendMagicLink(to: email)
    }

    func verifyEmailCode(email: String, code: String) async throws {
        try await auth.verifyEmailCode(email: email, code: code)
    }

    /// Route every incoming URL here; returns true if it was an auth callback we consumed.
    @discardableResult
    func handle(url: URL) async -> Bool {
        do {
            return try await auth.completeSignIn(from: url)
        } catch {
            lastError = String(describing: error)
            return AuthCallback.matches(url)
        }
    }

    // MARK: Account

    func updateDisplayName(_ name: String?) async throws {
        guard let user else { return }
        profile = try await profiles.updateDisplayName(name, for: user.id)
    }

    func updateDistrict(_ district: District?) async throws {
        guard let user else { return }
        profile = try await profiles.updateDistrict(district, for: user.id)
    }

    func signOut(everywhere: Bool) async throws {
        try await auth.signOut(everywhere: everywhere)
    }

    func deleteAccount() async throws {
        try await auth.deleteAccount()
        state = .signedOut
        profile = nil
    }
}
