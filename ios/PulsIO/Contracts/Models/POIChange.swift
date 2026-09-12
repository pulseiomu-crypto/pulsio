import Foundation

/// One row of the `poi_changes_since(p_since, p_limit)` RPC — the POI sync surface (ARCHITECTURE §3 kind 3,
/// §8). Ordered by `version`; `deleted` rows are tombstones carrying only `id` and `version`.
struct POIChange: Codable, Hashable, Sendable {
    static let rpc = "poi_changes_since"
    static let versionRPC = "poi_version"

    let id: Int64
    let version: Int64
    let deleted: Bool
    let type: POIType?
    let name: String?
    let lat: Double?
    let lng: Double?
    let district: String?
    let phone: String?
    let hours: String?
    let description: String?
    let rating: Double?
    let seg: [String]?
    let active: Bool
    let updatedAt: Date?

    enum CodingKeys: String, CodingKey {
        case id, version, deleted, type, name, lat, lng, district, phone, hours, description, rating, seg, active
        case updatedAt = "updated_at"
    }
}
