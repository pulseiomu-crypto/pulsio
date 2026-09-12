/// Mirrors `poiType` in `contracts/enums.json` (the `pulsio_poi.type` CHECK). Unknown values decode to
/// `.other` so a new type added upstream never breaks sync.
enum POIType: String, Codable, CaseIterable, Sendable {
    case beach, airport, landmark, viewpoint, hospital, fuel, restaurant, hotel, market, park, other
    case shelter, clinic, pharmacy, police, supermarket, mall, waterfall, hike, ferry, marina, helipad, town

    init(from decoder: any Decoder) throws {
        self = POIType(rawValue: try decoder.singleValueContainer().decode(String.self)) ?? .other
    }
}

/// Mirrors `poiDisplay` in `contracts/enums.json` — SPEC §20's pin/search split and §19's shelter rule.
/// "You browse a beach; you search for a pharmacy."
enum POIDisplayRules {
    /// Plotted on the map when active. For shelters, active means verified (the 13); the 136 approximate
    /// shelters are active=false and must never get a pin — a wrong shelter pin during a cyclone is dangerous.
    static let pinned: Set<POIType> = [.beach, .landmark, .waterfall, .hike, .park, .viewpoint, .airport, .ferry, .marina, .hospital, .shelter]
    /// Toggleable layers, off by default.
    static let layers: Set<POIType> = [.fuel]
    /// Findable by name/category, never plotted.
    static let searchOnly: Set<POIType> = [.pharmacy, .supermarket, .mall, .police, .clinic, .town]

    static func isPlotted(_ type: POIType, active: Bool, enabledLayers: Set<POIType>) -> Bool {
        guard active else { return false }
        return pinned.contains(type) || (layers.contains(type) && enabledLayers.contains(type))
    }
}
