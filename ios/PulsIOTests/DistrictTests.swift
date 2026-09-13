import CoreLocation
import Foundation
import Testing
@testable import PulsIO

struct DistrictTests {
    @Test func exactlyNineDistrictsSpelledAsThePipelineWritesThem() {
        #expect(District.allCases.count == 9)
        #expect(District.blackRiver.rawValue == "Black River")     // not "Rivière Noire" — joins pulsio_ceb.district
        #expect(District(rawValue: "Rivière du Rempart") == .riviereDuRempart)
        #expect(District(rawValue: "Rodrigues") == nil)             // outside the nine (SPEC §10 open item)
    }

    /// A CEB-shaped row for Rodrigues must decode with district = nil, not fail (SPEC §10).
    @Test func outOfScopeDistrictNeverFailsARow() throws {
        struct OutageRow: Decodable {
            let zone: String
            let district: District?
            enum CodingKeys: String, CodingKey { case zone, district }
            init(from decoder: any Decoder) throws {
                let c = try decoder.container(keyedBy: CodingKeys.self)
                zone = try c.decode(String.self, forKey: .zone)
                district = try District.decodeLenient(from: c, forKey: .district)
            }
        }
        let rows = try JSONDecoder().decode([OutageRow].self, from: Data(#"[{"zone":"Port Mathurin","district":"Rodrigues"},{"zone":"Rose Hill","district":"Plaines Wilhems"}]"#.utf8))
        #expect(rows.map(\.district) == [nil, .plainesWilhems])
    }

    @Test func profileDecodesUnknownDistrictAsNil() throws {
        let decoder = JSONDecoder()
        let row = try decoder.decode(Profile.self, from: Data(#"{"id":"6f1c2d3e-4a5b-4c6d-8e7f-901234567890","district":"Atlantis"}"#.utf8))
        #expect(row.district == nil)
        let ok = try decoder.decode(Profile.self, from: Data(#"{"id":"6f1c2d3e-4a5b-4c6d-8e7f-901234567890","district":"Moka"}"#.utf8))
        #expect(ok.district == .moka)
    }
}

struct DistrictResolverTests {
    private func poi(_ id: Int64, _ lat: Double, _ lng: Double, _ district: String?) -> POIChange {
        POIChange(id: id, version: id, deleted: false, type: .beach, name: "p\(id)", lat: lat, lng: lng, district: district,
                  phone: nil, hours: nil, description: nil, rating: nil, seg: ["all"], active: true, locationPrecision: .exact, updatedAt: nil)
    }

    @Test func votesAmongNearestPOIs() async throws {
        let store = try POIStore.inMemory()
        try await store.apply([
            poi(1, -20.200, 57.500, "Moka"), poi(2, -20.201, 57.501, "Moka"), poi(3, -20.202, 57.502, "Plaines Wilhems"),
            poi(4, -20.203, 57.503, "Moka"), poi(5, -20.204, 57.504, "Plaines Wilhems"),
        ])
        let resolver = DistrictResolver(store: store, voters: 5)
        #expect(try await resolver.district(for: CLLocationCoordinate2D(latitude: -20.2, longitude: 57.5)) == .moka)
    }

    @Test func nothingNearbyResolvesToNil() async throws {
        let store = try POIStore.inMemory()
        try await store.apply([poi(1, -20.2, 57.5, "Moka")])
        let resolver = DistrictResolver(store: store)
        // Rodrigues is ~560 km east of the main island.
        #expect(try await resolver.district(for: CLLocationCoordinate2D(latitude: -19.7, longitude: 63.4)) == nil)
        #expect(try await DistrictResolver(store: try POIStore.inMemory()).district(for: CLLocationCoordinate2D(latitude: -20.2, longitude: 57.5)) == nil)
    }
}

/// DistrictStore never sees a coordinate after resolution and persists only the district + source.
struct DistrictStoreTests {
    struct NoAuth: AuthRepository {
        func sessionEvents() -> AsyncStream<SessionEvent> { AsyncStream { $0.finish() } }
        func currentUser() -> AuthUser? { nil }
        func signInWithApple(idToken: String, nonce: String) async throws {}
        func signInWithGoogle() async throws {}
        func sendMagicLink(to email: String) async throws {}
        func verifyEmailCode(email: String, code: String) async throws {}
        func completeSignIn(from url: URL) async throws -> Bool { false }
        func signOut(everywhere: Bool) async throws {}
        func deleteAccount() async throws {}
    }
    struct NoProfiles: ProfileRepository {
        struct Unused: Error {}
        func ensureProfile(for userID: UUID) async throws -> Profile { throw Unused() }
        func updateDisplayName(_ name: String?, for userID: UUID) async throws -> Profile { throw Unused() }
        func updateDistrict(_ district: District?, for userID: UUID) async throws -> Profile { throw Unused() }
    }
    struct NoEmergency: EmergencyRepository {
        func current() async throws -> EmergencyState { .none }
    }

    @Test @MainActor func manualChoicePersistsAcrossLaunches() async throws {
        let defaults = UserDefaults(suiteName: "DistrictStoreTests.\(UUID().uuidString)")!
        let session = SessionStore(auth: NoAuth(), profiles: NoProfiles(), emergencies: NoEmergency())
        let resolver = DistrictResolver(store: try POIStore.inMemory())

        let first = DistrictStore(defaults: defaults, location: LocationService(), resolver: resolver, session: session)
        #expect(first.district == nil)
        await first.setManual(.savanne)
        #expect(first.district == .savanne && first.source == .manual)

        let second = DistrictStore(defaults: defaults, location: LocationService(), resolver: resolver, session: session)
        #expect(second.district == .savanne && second.source == .manual)
        // Only the district and how it was set are on disk — no coordinate keys of any kind.
        let keys = Set(defaults.dictionaryRepresentation().keys.filter { $0.hasPrefix("district") })
        #expect(keys == ["district", "district.source"])
    }
}
