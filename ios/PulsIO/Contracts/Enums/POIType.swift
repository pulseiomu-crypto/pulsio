/// Mirrors `poiType` in `contracts/enums.json` (the `pulsio_poi.type` CHECK). Unknown values decode to
/// `.other` so a new type added upstream never breaks sync.
enum POIType: String, Codable, CaseIterable, Sendable {
    case beach, airport, landmark, viewpoint, hospital, fuel, restaurant, hotel, market, park, other
    case shelter, clinic, pharmacy, police, supermarket, mall, waterfall, hike, ferry, marina, helipad, town

    init(from decoder: any Decoder) throws {
        self = POIType(rawValue: try decoder.singleValueContainer().decode(String.self)) ?? .other
    }
}

/// Mirrors `locationPrecision` in `contracts/enums.json` (SPEC §19). `active` says open/closed; this says
/// whether the coordinate is trustworthy enough to pin.
enum LocationPrecision: String, Codable, CaseIterable, Sendable {
    case exact, approximate

    init(from decoder: any Decoder) throws {
        self = LocationPrecision(rawValue: try decoder.singleValueContainer().decode(String.self)) ?? .exact
    }
}

/// Mirrors `poiDisplay` in `contracts/enums.json` — SPEC §20's pin/search split, §19's shelter rule and the
/// emergency pattern. "You browse a beach; you search for a pharmacy."
enum POIDisplayRules {
    /// Plotted on the map when active. Shelters additionally need an exact location — the 136 approximate
    /// shelters must never get a pin; a wrong shelter pin during a cyclone is dangerous.
    static let pinned: Set<POIType> = [.beach, .landmark, .waterfall, .hike, .park, .viewpoint, .airport, .ferry, .marina, .hospital, .shelter]
    /// Toggleable layers, off by default.
    static let layers: Set<POIType> = [.fuel]
    /// Findable by name/category, never plotted.
    static let searchOnly: Set<POIType> = [.pharmacy, .supermarket, .mall, .police, .clinic, .town]
    /// Plotted only while `pulsio_emergency_state` says an emergency is active (SPEC §20 emergency pattern).
    static let emergencyOnly: Set<POIType> = [.helipad]
    /// Types whose pins require an exact coordinate.
    static let requiresExactLocation: Set<POIType> = [.shelter]

    static func isPlotted(_ type: POIType, active: Bool, precision: LocationPrecision = .exact,
                          enabledLayers: Set<POIType>, emergencyActive: Bool = false) -> Bool {
        guard active else { return false }
        if requiresExactLocation.contains(type), precision != .exact { return false }
        if pinned.contains(type) { return true }
        if layers.contains(type) { return enabledLayers.contains(type) }
        if emergencyOnly.contains(type) { return emergencyActive }
        return false
    }
}
