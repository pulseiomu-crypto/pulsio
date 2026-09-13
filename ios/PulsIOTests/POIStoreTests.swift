import CoreLocation
import Foundation
import Testing
@testable import PulsIO

/// The device POI store: delta application (insert/update/deactivate/tombstone), the high-water mark,
/// SPEC §20 plotting rules, and on-device proximity.
struct POIStoreTests {
    private func change(id: Int64, version: Int64, type: POIType = .beach, name: String = "x", lat: Double = -20.2, lng: Double = 57.5,
                        active: Bool = true, deleted: Bool = false, phone: String? = nil, precision: LocationPrecision = .exact,
                        district: String? = nil) -> POIChange {
        POIChange(id: id, version: version, deleted: deleted, type: deleted ? nil : type, name: deleted ? nil : name,
                  lat: deleted ? nil : lat, lng: deleted ? nil : lng, district: district, phone: phone, hours: nil, description: nil,
                  rating: nil, seg: ["all"], active: active, locationPrecision: precision, updatedAt: nil)
    }

    @Test func appliesInsertsAndAdvancesHighWater() async throws {
        let store = try POIStore.inMemory()
        #expect(try await store.highWaterVersion() == 0)
        let result = try await store.apply([change(id: 1, version: 10), change(id: 2, version: 12, type: .hospital)])
        #expect(result.upserted == 2 && result.deleted == 0 && result.highWater == 12)
        #expect(try await store.count() == 2)
        #expect(try await store.highWaterVersion() == 12)
    }

    @Test func updatesDeactivatesAndTombstones() async throws {
        let store = try POIStore.inMemory()
        try await store.apply([change(id: 1, version: 1, name: "Old"), change(id: 2, version: 2, type: .hospital), change(id: 3, version: 3, type: .shelter)])
        // Rename 1, deactivate 2 (closed hospital), hard-delete 3.
        let result = try await store.apply([change(id: 1, version: 4, name: "New"), change(id: 2, version: 5, type: .hospital, active: false), change(id: 3, version: 6, deleted: true)])
        #expect(result.upserted == 2 && result.deleted == 1 && result.highWater == 6)
        let plotted = try await store.plotted(enabledLayers: [])
        #expect(plotted.map(\.name) == ["New"])          // 2 is inactive, 3 is gone
        #expect(try await store.count() == 2)             // inactive rows are kept (search-only shelters need this)
        #expect(try await store.count(activeOnly: true) == 1)
    }

    @Test func reapplyingAPageIsHarmless() async throws {
        let store = try POIStore.inMemory()
        let page = [change(id: 1, version: 1), change(id: 2, version: 2)]
        try await store.apply(page)
        let again = try await store.apply(page)
        #expect(again.highWater == 2)
        #expect(try await store.count() == 2)
    }

    @Test func emptyPageKeepsHighWater() async throws {
        let store = try POIStore.inMemory()
        try await store.apply([change(id: 1, version: 7)])
        #expect(try await store.apply([]).highWater == 7)
    }

    @Test func plotsOnlySpecPinTypesAndEnabledLayers() async throws {
        let store = try POIStore.inMemory()
        try await store.apply([
            change(id: 1, version: 1, type: .beach), change(id: 2, version: 2, type: .pharmacy),
            change(id: 3, version: 3, type: .fuel), change(id: 4, version: 4, type: .shelter),
            change(id: 5, version: 5, type: .shelter, precision: .approximate),   // approximate shelter: never a pin
            change(id: 6, version: 6, type: .helipad),                             // emergency-only
            change(id: 7, version: 7, type: .hospital, active: false),             // closed: hidden
        ])
        #expect(Set(try await store.plotted(enabledLayers: []).map(\.id)) == [1, 4])
        #expect(Set(try await store.plotted(enabledLayers: [.fuel]).map(\.id)) == [1, 3, 4])
        #expect(Set(try await store.plotted(enabledLayers: [], emergencyActive: true).map(\.id)) == [1, 4, 6])
    }

    @Test func nearestShelterSkipsApproximateOnes() async throws {
        let store = try POIStore.inMemory()
        try await store.apply([
            change(id: 1, version: 1, type: .shelter, name: "Approx (closer)", lat: -20.20, lng: 57.50, precision: .approximate),
            change(id: 2, version: 2, type: .shelter, name: "Exact", lat: -20.25, lng: 57.55),
        ])
        let origin = CLLocationCoordinate2D(latitude: -20.20, longitude: 57.50)
        #expect(try await store.nearest(.shelter, to: origin).map(\.poi.name) == ["Exact"])
        #expect(try await store.nearest(.shelter, to: origin, exactOnly: false).map(\.poi.name) == ["Approx (closer)", "Exact"])
    }

    @Test func nearestDistrictsFeedTheOnDeviceVote() async throws {
        let store = try POIStore.inMemory()
        try await store.apply([
            change(id: 1, version: 1, lat: -20.20, lng: 57.50, district: "Port Louis"),
            change(id: 2, version: 2, lat: -20.21, lng: 57.51, district: "Port Louis"),
            change(id: 3, version: 3, lat: -20.22, lng: 57.52, district: nil),          // no district: not a voter
            change(id: 4, version: 4, lat: -20.40, lng: 57.70, district: "Grand Port"),
        ])
        let voters = try await store.nearestDistricts(to: CLLocationCoordinate2D(latitude: -20.20, longitude: 57.50), limit: 3)
        #expect(voters.map(\.district) == ["Port Louis", "Port Louis", "Grand Port"])
    }

    @Test func nearestIsComputedOnDevice() async throws {
        let store = try POIStore.inMemory()
        try await store.apply([
            change(id: 1, version: 1, type: .shelter, name: "Near", lat: -20.20, lng: 57.50),
            change(id: 2, version: 2, type: .shelter, name: "Far", lat: -20.40, lng: 57.70),
            change(id: 3, version: 3, type: .shelter, name: "Inactive", lat: -20.20, lng: 57.50, active: false),
            change(id: 4, version: 4, type: .hospital, name: "Wrong type", lat: -20.20, lng: 57.50),
        ])
        let result = try await store.nearest(.shelter, to: CLLocationCoordinate2D(latitude: -20.21, longitude: 57.51), limit: 5)
        #expect(result.map(\.poi.name) == ["Near", "Far"])
        #expect(result[0].metres < 2_000 && result[1].metres > 20_000)
    }
}

struct POIDisplayRulesTests {
    @Test(arguments: [POIType.beach, .landmark, .waterfall, .hike, .park, .viewpoint, .airport, .ferry, .marina, .hospital, .shelter])
    func pinnedTypesPlotWhenActive(type: POIType) {
        #expect(POIDisplayRules.isPlotted(type, active: true, enabledLayers: []))
        #expect(!POIDisplayRules.isPlotted(type, active: false, enabledLayers: []))
    }

    @Test(arguments: [POIType.pharmacy, .supermarket, .mall, .police, .clinic, .town, .restaurant, .hotel, .market, .other])
    func searchOnlyAndUnlistedTypesNeverPlot(type: POIType) {
        #expect(!POIDisplayRules.isPlotted(type, active: true, enabledLayers: [.fuel], emergencyActive: true))
    }

    @Test func helipadsSurfaceOnlyDuringAnEmergency() {
        #expect(!POIDisplayRules.isPlotted(.helipad, active: true, enabledLayers: []))
        #expect(POIDisplayRules.isPlotted(.helipad, active: true, enabledLayers: [], emergencyActive: true))
    }

    @Test func approximateSheltersAreNeverPinnedEvenInAnEmergency() {
        #expect(POIDisplayRules.isPlotted(.shelter, active: true, precision: .exact, enabledLayers: []))
        #expect(!POIDisplayRules.isPlotted(.shelter, active: true, precision: .approximate, enabledLayers: [], emergencyActive: true))
        // Precision only gates shelters; a hospital's coordinate is trusted as-is.
        #expect(POIDisplayRules.isPlotted(.hospital, active: true, precision: .approximate, enabledLayers: []))
    }

    @Test func fuelIsALayerOffByDefault() {
        #expect(!POIDisplayRules.isPlotted(.fuel, active: true, enabledLayers: []))
        #expect(POIDisplayRules.isPlotted(.fuel, active: true, enabledLayers: [.fuel]))
    }
}
