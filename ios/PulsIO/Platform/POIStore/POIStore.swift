import CoreLocation
import Foundation
import GRDB

/// The device-resident POI set (ARCHITECTURE §8): the foundation of on-device proximity (SPEC §10) and of
/// offline mode. Read-only reference data — the only writer is `POISync`, which applies server deltas
/// transactionally and records the high-water `version`.
final class POIStore: Sendable {
    struct ApplyResult: Equatable, Sendable {
        var upserted = 0
        var deleted = 0
        var highWater: Int64 = 0
    }

    private let db: DatabaseQueue
    private static let versionKey = "poi_version"

    /// On-disk store in Application Support; use `inMemory()` for tests.
    static func onDisk() throws -> POIStore {
        let dir = try FileManager.default.url(for: .applicationSupportDirectory, in: .userDomainMask, appropriateFor: nil, create: true)
            .appendingPathComponent("PulsIO", isDirectory: true)
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return try POIStore(queue: DatabaseQueue(path: dir.appendingPathComponent("poi.sqlite").path))
    }

    static func inMemory() throws -> POIStore {
        try POIStore(queue: DatabaseQueue())
    }

    private init(queue: DatabaseQueue) throws {
        db = queue
        try Self.migrator.migrate(db)
    }

    private static var migrator: DatabaseMigrator {
        var m = DatabaseMigrator()
        m.registerMigration("v1_poi") { db in
            try db.create(table: "poi") { t in
                t.primaryKey("id", .integer)
                t.column("type", .text).notNull().indexed()
                t.column("name", .text).notNull()
                t.column("lat", .double).notNull()
                t.column("lng", .double).notNull()
                t.column("district", .text)
                t.column("phone", .text)
                t.column("hours", .text)
                t.column("description", .text)
                t.column("rating", .double)
                t.column("seg", .jsonText).notNull()
                t.column("active", .boolean).notNull().indexed()
                t.column("version", .integer).notNull()
                t.column("updatedAt", .datetime)
            }
            try db.create(table: "syncState") { t in
                t.primaryKey("key", .text)
                t.column("value", .integer).notNull()
            }
        }
        m.registerMigration("v2_location_precision") { db in
            try db.alter(table: "poi") { t in
                t.add(column: "locationPrecision", .text).notNull().defaults(to: LocationPrecision.exact.rawValue)
            }
        }
        return m
    }

    // MARK: Sync

    func highWaterVersion() async throws -> Int64 {
        try await db.read { db in
            try Int64.fetchOne(db, sql: "SELECT value FROM syncState WHERE key = ?", arguments: [Self.versionKey]) ?? 0
        }
    }

    /// Apply one page of server changes atomically: upsert live rows, drop tombstoned ids, advance the
    /// high-water mark to the page's last version. Re-applying the same page is harmless.
    @discardableResult
    func apply(_ changes: [POIChange]) async throws -> ApplyResult {
        guard !changes.isEmpty else {
            return ApplyResult(highWater: try await highWaterVersion())
        }
        return try await db.write { db in
            var result = ApplyResult()
            for change in changes {
                if change.deleted {
                    try db.execute(sql: "DELETE FROM poi WHERE id = ?", arguments: [change.id])
                    result.deleted += 1
                } else if let record = POIRecord(change: change) {
                    try record.upsert(db)
                    result.upserted += 1
                }
            }
            let last = changes.map(\.version).max() ?? 0
            let current = try Int64.fetchOne(db, sql: "SELECT value FROM syncState WHERE key = ?", arguments: [Self.versionKey]) ?? 0
            result.highWater = max(current, last)
            try db.execute(sql: "INSERT OR REPLACE INTO syncState (key, value) VALUES (?, ?)", arguments: [Self.versionKey, result.highWater])
            return result
        }
    }

    // MARK: Queries

    func count(activeOnly: Bool = false) async throws -> Int {
        try await db.read { db in
            activeOnly ? try POIRecord.filter(Column("active") == true).fetchCount(db) : try POIRecord.fetchCount(db)
        }
    }

    /// Everything the map should plot, per SPEC §20 rules, the enabled optional layers, and whether an
    /// emergency is active (emergency-only categories, e.g. helipads).
    func plotted(enabledLayers: Set<POIType>, emergencyActive: Bool = false) async throws -> [POIRecord] {
        var types = POIDisplayRules.pinned.union(POIDisplayRules.layers.intersection(enabledLayers))
        if emergencyActive { types.formUnion(POIDisplayRules.emergencyOnly) }
        let typeNames = types.map(\.rawValue)
        let exactOnly = POIDisplayRules.requiresExactLocation.map(\.rawValue)
        return try await db.read { db in
            try POIRecord
                .filter(Column("active") == true && typeNames.contains(Column("type")))
                .filter(!exactOnly.contains(Column("type")) || Column("locationPrecision") == LocationPrecision.exact.rawValue)
                .order(Column("type"), Column("name"))
                .fetchAll(db)
        }
    }

    /// Districts of the nearest POIs that carry one — the on-device input for GPS → district (SPEC §10).
    /// Returns (district, metres) nearest-first; the caller votes.
    func nearestDistricts(to origin: CLLocationCoordinate2D, limit: Int = 7) async throws -> [(district: String, metres: CLLocationDistance)] {
        let candidates = try await db.read { db in
            try POIRecord.filter(Column("district") != nil && Column("active") == true).fetchAll(db)
        }
        let from = CLLocation(latitude: origin.latitude, longitude: origin.longitude)
        return candidates
            .compactMap { poi -> (String, CLLocationDistance)? in
                guard let district = poi.district else { return nil }
                return (district, CLLocation(latitude: poi.lat, longitude: poi.lng).distance(from: from))
            }
            .sorted { $0.1 < $1.1 }
            .prefix(limit)
            .map { (district: $0.0, metres: $0.1) }
    }

    /// Centre of mass of a district's POIs — a district-grade reference point when there's no GPS fix
    /// (nearest weather station, sunset). Nil if the store has no POIs for it.
    func districtCentroid(_ district: District) async throws -> CLLocationCoordinate2D? {
        let rows = try await db.read { db in
            try POIRecord.filter(Column("district") == district.rawValue && Column("active") == true).fetchAll(db)
        }
        guard !rows.isEmpty else { return nil }
        let lat = rows.map(\.lat).reduce(0, +) / Double(rows.count)
        let lng = rows.map(\.lng).reduce(0, +) / Double(rows.count)
        return CLLocationCoordinate2D(latitude: lat, longitude: lng)
    }

    /// Nearest active POIs of a type to a coordinate — computed here, on the device (SPEC §10 privacy rule).
    /// `exactOnly` drops approximate coordinates (default for shelters: "nearest shelter" must be one you can drive to).
    func nearest(_ type: POIType, to origin: CLLocationCoordinate2D, limit: Int = 3, exactOnly: Bool? = nil) async throws -> [(poi: POIRecord, metres: CLLocationDistance)] {
        let exact = exactOnly ?? POIDisplayRules.requiresExactLocation.contains(type)
        let candidates = try await db.read { db in
            var q = POIRecord.filter(Column("type") == type.rawValue && Column("active") == true)
            if exact { q = q.filter(Column("locationPrecision") == LocationPrecision.exact.rawValue) }
            return try q.fetchAll(db)
        }
        let from = CLLocation(latitude: origin.latitude, longitude: origin.longitude)
        return candidates
            .map { ($0, CLLocation(latitude: $0.lat, longitude: $0.lng).distance(from: from)) }
            .sorted { $0.1 < $1.1 }
            .prefix(limit)
            .map { (poi: $0.0, metres: $0.1) }
    }
}
