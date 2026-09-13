import CoreLocation
import Foundation

/// GPS → district, on the device (SPEC §10). Votes among the nearest POIs that carry a district: cheap, needs
/// no polygon data, and good to district grade — the only grade we keep. Returns nil when nothing is near
/// (off-island, or the store hasn't synced yet). Replaceable with real district polygons behind this same call.
struct DistrictResolver: Sendable {
    let store: POIStore
    /// Nearest POI must be within this to trust the vote.
    var maxDistanceMetres: CLLocationDistance = 15_000
    var voters = 7

    func district(for coordinate: CLLocationCoordinate2D) async throws -> District? {
        let nearest = try await store.nearestDistricts(to: coordinate, limit: voters)
        guard let closest = nearest.first, closest.metres <= maxDistanceMetres else { return nil }
        var tally: [District: Int] = [:]
        for (name, _) in nearest {
            if let district = District(rawValue: name) { tally[district, default: 0] += 1 }
        }
        // Ties break toward the closest POI's district.
        return tally.max { a, b in
            a.value != b.value ? a.value < b.value : (District(rawValue: closest.district) == b.key)
        }?.key
    }
}
