import Foundation
import Testing
@testable import PulsIO

struct PreferencesStoreTests {
    @MainActor private func make(_ suite: UserDefaults) -> PreferencesStore {
        PreferencesStore(defaults: suite, session: SessionStore(auth: DistrictStoreTests.NoAuth(), profiles: DistrictStoreTests.NoProfiles(), emergencies: DistrictStoreTests.NoEmergency()))
    }

    @Test @MainActor func capsAtThreeAndPersists() async {
        let suite = UserDefaults(suiteName: "PreferencesStoreTests.\(UUID().uuidString)")!
        let store = make(suite)
        #expect(!store.onboardingComplete)
        store.setUserType(.tourist)
        #expect(store.toggle(.ceb) && store.toggle(.weather) && store.toggle(.cyclone))
        #expect(!store.toggle(.fuel))                       // the cap refuses a fourth
        #expect(store.toggle(.ceb))                         // toggling off works past the cap
        #expect(store.priorities == [.weather, .cyclone])
        await store.completeOnboarding()

        let again = make(suite)
        #expect(again.userType == .tourist && again.priorities == [.weather, .cyclone] && again.onboardingComplete)
    }

    @Test @MainActor func profilePreferencesWinOnReconcile() async throws {
        let suite = UserDefaults(suiteName: "PreferencesStoreTests.\(UUID().uuidString)")!
        let store = make(suite)
        store.toggle(.fuel)
        let profile = try JSONDecoder().decode(Profile.self, from: Data(#"{"id":"6f1c2d3e-4a5b-4c6d-8e7f-901234567890","user_type":"pro","priorities":["cyclone","ceb"]}"#.utf8))
        await store.reconcile(with: profile)
        #expect(store.priorities == [.cyclone, .ceb] && store.userType == .pro)
    }

    @Test func prioritiesMirrorTheContract() {
        #expect(Priority.allCases.map(\.rawValue) == ["ceb", "weather", "traffic", "news", "cyclone", "fuel"])
        #expect(Priority.maxSelected == 3)
    }
}
