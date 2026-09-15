import Foundation
import Observation

/// What onboarding collects: user type and up to three priorities, plus whether onboarding was completed.
/// Held on the device always (onboarding runs signed-out) and reconciled to the profile on sign-in — the
/// same pattern as the district: the profile wins if it already has preferences, else the device's are pushed up.
@MainActor
@Observable
final class PreferencesStore {
    private(set) var userType: UserType?
    private(set) var priorities: [Priority] = []
    private(set) var onboardingComplete: Bool

    private let defaults: UserDefaults
    private let session: SessionStore
    private static let typeKey = "prefs.userType", prioritiesKey = "prefs.priorities", doneKey = "prefs.onboardingComplete"

    init(defaults: UserDefaults = .standard, session: SessionStore) {
        self.defaults = defaults
        self.session = session
        userType = defaults.string(forKey: Self.typeKey).flatMap(UserType.init(rawValue:))
        priorities = (defaults.stringArray(forKey: Self.prioritiesKey) ?? []).compactMap(Priority.init(rawValue:))
        onboardingComplete = defaults.bool(forKey: Self.doneKey)
    }

    func setUserType(_ type: UserType) {
        userType = type
        defaults.set(type.rawValue, forKey: Self.typeKey)
    }

    /// Toggle a priority; at most `Priority.maxSelected`. Returns false when the cap refuses the add.
    @discardableResult
    func toggle(_ priority: Priority) -> Bool {
        if let i = priorities.firstIndex(of: priority) {
            priorities.remove(at: i)
        } else {
            guard priorities.count < Priority.maxSelected else { return false }
            priorities.append(priority)
        }
        defaults.set(priorities.map(\.rawValue), forKey: Self.prioritiesKey)
        return true
    }

    /// Done (or skipped) — either way the app opens; skipped users get the default panel order.
    func completeOnboarding() async {
        onboardingComplete = true
        defaults.set(true, forKey: Self.doneKey)
        if session.isSignedIn { await push() }
    }

    /// Sign-in binds the device's preferences to the profile (FRONTEND §A: "sign-in later migrates them").
    func reconcile(with profile: Profile?) async {
        guard let profile else { return }
        if !profile.priorities.isEmpty {
            priorities = profile.priorities.compactMap(Priority.init(rawValue:))
            defaults.set(priorities.map(\.rawValue), forKey: Self.prioritiesKey)
            userType = profile.userType
            defaults.set(profile.userType.rawValue, forKey: Self.typeKey)
        } else if !priorities.isEmpty || userType != nil {
            await push()
        }
    }

    /// After an edit in Settings: mirror to the profile if signed in (onboarding calls this via completeOnboarding).
    func syncIfSignedIn() async {
        if session.isSignedIn { await push() }
    }

    private func push() async {
        do { try await session.updatePreferences(userType: userType, priorities: priorities.map(\.rawValue)) }
        catch { /* the profile keeps its previous values; the device copy still drives the panel */ }
    }
}
