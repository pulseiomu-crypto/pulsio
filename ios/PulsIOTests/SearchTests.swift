import CoreLocation
import Foundation
import Testing
@testable import PulsIO

struct POIContactsTests {
    @Test func parsesRolesAndNumbersFromTheShelterList() {
        let contacts = POIContacts.parse("Centre 4520237 · Supervisor 4522641 59029210")
        #expect(contacts.map(\.number) == ["4520237", "4522641", "59029210"])
        #expect(contacts.map(\.role) == [.centre, .supervisor, .supervisor])
        #expect(contacts[0].display == "452 0237" && contacts[2].display == "5902 9210")
        #expect(contacts[0].url?.absoluteString == "tel:4520237")
    }

    @Test func handlesSlashesDuplicatesAndBareNumbers() {
        let a = POIContacts.parse("Centre 6274542 6640086 57234915 · Supervisor 6640086 57234915")
        #expect(a.map(\.number) == ["6274542", "6640086", "57234915"])      // duplicates collapsed, first role kept
        let b = POIContacts.parse("Centre 4130414 · Supervisor 4188718 / 57024410")
        #expect(b.map(\.number) == ["4130414", "4188718", "57024410"] && b[2].role == .supervisor)
        #expect(POIContacts.parse("Centre 54758076 6344296 59077570").count == 3)
        #expect(POIContacts.parse(nil).isEmpty && POIContacts.parse("no phone").isEmpty)
        #expect(POIContacts.parse("999").isEmpty)                            // too short to be a Mauritian line
    }

    @Test func villageComesFromTheDescriptionOrTheName() {
        let a = POIRecord(id: 1, type: .shelter, name: "Bambous Social Welfare Centre", lat: -20.26, lng: 57.4,
                          description: "Cyclone evacuee centre · geocode: village-level only: pin is Bambous centre, not the building · APPROXIMATE", version: 1)
        #expect(POIContacts.village(for: a) == "Bambous")
        let b = POIRecord(id: 2, type: .shelter, name: "Anse Jonchée Sub-Hall Royal No., Anse Jonchée", lat: -20.3, lng: 57.7, version: 1)
        #expect(POIContacts.village(for: b) == "Anse Jonchée")
        #expect(POIContacts.village(for: POIRecord(id: 3, type: .pharmacy, name: "Pharmacie Nouvelle", lat: 0, lng: 0, version: 1)) == nil)
    }
}

struct POISearchTests {
    private func poi(_ id: Int64, _ type: POIType, _ name: String, district: String? = "Moka", precision: LocationPrecision = .exact, lat: Double = -20.2, lng: Double = 57.5) -> POIChange {
        POIChange(id: id, version: id, deleted: false, type: type, name: name, lat: lat, lng: lng, district: district, phone: nil, hours: nil, description: nil,
                  rating: nil, seg: ["all"], active: true, locationPrecision: precision, updatedAt: nil)
    }

    @Test func findsByNameCategoryAndDistrictAcrossSurfacedTypes() async throws {
        let store = try POIStore.inMemory()
        try await store.apply([
            poi(1, .pharmacy, "Pharmacie Nouvelle"), poi(2, .pharmacy, "Pharmacie Centrale", district: "Flacq"),
            poi(3, .beach, "Flic en Flac beach", district: "Black River"), poi(4, .shelter, "Bambous Village Hall", precision: .approximate),
            poi(5, .restaurant, "Pharmacie Bistro"),        // not surfaced by §20 → never a hit
            poi(6, .helipad, "Pharmacy Helipad"),
        ])
        #expect(Set(try await store.search("pharmacie").map(\.id)) == [1, 2])
        #expect(try await store.search("", types: [.pharmacy]).count == 2)
        #expect(try await store.search("flacq").map(\.id) == [2])
        #expect(try await store.search("bambous").map(\.id) == [4])            // approximate shelters are findable
        #expect(try await store.search("beach").map(\.id) == [3])              // "beach" matches the type too
        #expect(try await store.search("").count == 4)                         // 5 and 6 never surface
    }

    @Test @MainActor func sortsByDistanceWhenThereIsAReferenceElseAlphabetically() async throws {
        let store = try POIStore.inMemory()
        try await store.apply([
            poi(1, .pharmacy, "Zed Pharmacy", lat: -20.20, lng: 57.50),
            poi(2, .pharmacy, "Alpha Pharmacy", lat: -20.40, lng: 57.70),
        ])
        let session = SessionStore(auth: DistrictStoreTests.NoAuth(), profiles: DistrictStoreTests.NoProfiles(), emergencies: DistrictStoreTests.NoEmergency())
        let defaults = UserDefaults(suiteName: "POISearchTests.\(UUID().uuidString)")!
        let districts = DistrictStore(defaults: defaults, location: LocationService(), resolver: DistrictResolver(store: store), session: session)
        let model = SearchViewModel(store: store, districts: districts) { _ in [] }

        model.select(.pharmacy)
        await model.run()
        #expect(model.ordering == .alphabetical && model.hits.map(\.poi.name) == ["Alpha Pharmacy", "Zed Pharmacy"])

        // A district gives a reference point (its POI centroid) → nearest first, with a distance on each hit.
        try await store.apply([poi(9, .town, "Moka town", district: "Moka", lat: -20.21, lng: 57.51)])
        await districts.setManual(.moka)
        await model.run()
        #expect(model.ordering == .distance && model.hits.map(\.poi.name) == ["Zed Pharmacy", "Alpha Pharmacy"])
        #expect(model.hits.allSatisfy { $0.metres != nil })
    }
}
