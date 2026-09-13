import CoreLocation
import Foundation
import GRDB

/// A POI as held on the device — the synced copy of `pulsio_poi` (minus photos). Rows are kept even when
/// `active == false` (approximate shelters are search-only, SPEC §19); the map applies `POIDisplayRules`.
struct POIRecord: Codable, Hashable, Sendable, Identifiable, FetchableRecord, PersistableRecord {
    static let databaseTableName = "poi"

    var id: Int64
    var type: POIType
    var name: String
    var lat: Double
    var lng: Double
    var district: String?
    var phone: String?
    var hours: String?
    var description: String?
    var rating: Double?
    /// Audience segments (`all`, `tourist`, `mauritian`, `pro`), stored as JSON.
    var seg: [String]
    var active: Bool
    var locationPrecision: LocationPrecision
    var version: Int64
    var updatedAt: Date?

    var coordinate: CLLocationCoordinate2D { CLLocationCoordinate2D(latitude: lat, longitude: lng) }

    /// Build from a sync row; nil for tombstones or rows missing the non-null columns.
    init?(change: POIChange) {
        guard !change.deleted, let type = change.type, let name = change.name, let lat = change.lat, let lng = change.lng else { return nil }
        id = change.id
        self.type = type
        self.name = name
        self.lat = lat
        self.lng = lng
        district = change.district
        phone = change.phone
        hours = change.hours
        description = change.description
        rating = change.rating
        seg = change.seg ?? ["all"]
        active = change.active
        locationPrecision = change.locationPrecision ?? .exact
        version = change.version
        updatedAt = change.updatedAt
    }

    init(id: Int64, type: POIType, name: String, lat: Double, lng: Double, district: String? = nil, phone: String? = nil,
         hours: String? = nil, description: String? = nil, rating: Double? = nil, seg: [String] = ["all"],
         active: Bool = true, locationPrecision: LocationPrecision = .exact, version: Int64, updatedAt: Date? = nil) {
        self.id = id; self.type = type; self.name = name; self.lat = lat; self.lng = lng; self.district = district
        self.phone = phone; self.hours = hours; self.description = description; self.rating = rating; self.seg = seg
        self.active = active; self.locationPrecision = locationPrecision; self.version = version; self.updatedAt = updatedAt
    }
}
