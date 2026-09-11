import Foundation
import Observation

/// The sign-in gate. A feature asks `perform(.submitReport) { … }`; if the policy allows it the closure runs
/// now, otherwise the sign-in sheet is presented and the closure runs after a successful sign-in
/// (FRONTEND §4: "on success, the original action resumes"). Cancelling the sheet drops it.
@MainActor
@Observable
final class AccessGate {
    struct Pending {
        let act: Act?
        let resume: @MainActor () async -> Void
    }

    private(set) var pending: Pending?
    var isPresentingSignIn = false

    private let policy = AccessPolicy()
    private let session: SessionStore

    init(session: SessionStore) {
        self.session = session
    }

    /// The act the sheet is being shown for, so it can say *why* ("Sign in to submit a report").
    var reason: Act? { pending?.act }

    func perform(_ act: Act, _ action: @escaping @MainActor () async -> Void) {
        switch policy.decide(act, isSignedIn: session.isSignedIn, emergency: session.emergency) {
        case .allowed:
            Task { await action() }
        case .requiresSignIn:
            pending = Pending(act: act, resume: action)
            isPresentingSignIn = true
        }
    }

    /// Open the sheet with no act attached (the profile button while signed out).
    func presentSignIn() {
        pending = nil
        isPresentingSignIn = true
    }

    func cancel() {
        pending = nil
        isPresentingSignIn = false
    }

    /// Call when the session becomes signed-in: closes the sheet and resumes whatever was waiting.
    func sessionDidSignIn() {
        isPresentingSignIn = false
        guard let pending else { return }
        self.pending = nil
        Task { await pending.resume() }
    }
}
