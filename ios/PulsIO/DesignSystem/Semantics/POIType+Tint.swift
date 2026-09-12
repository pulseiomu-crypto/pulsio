import SwiftUI

/// Colour is meaning (SPEC): sky = weather & marine, amber = warnings, coral = danger & emergency,
/// green = good & fuel, purple = events & pro, teal = brand & tourist. Airport rides with the marine group
/// as "getting around" — the one call SPEC doesn't make explicitly.
extension POIType {
    var tintHex: UInt32 {
        switch self {
        case .beach, .landmark, .waterfall, .hike, .park, .viewpoint, .restaurant, .hotel, .market: Palette.Hex.teal
        case .ferry, .marina, .airport, .helipad: Palette.Hex.sky
        case .hospital, .shelter, .clinic, .police: Palette.Hex.coral
        case .fuel: Palette.Hex.green
        case .pharmacy, .supermarket, .mall, .town, .other: Palette.Hex.muted
        }
    }

    var tint: Color { Color(hex: tintHex) }
    var tintString: String { Palette.Hex.string(tintHex) }

    /// Shelters are drawn emphasised: larger, light stroke — the pin that must be unmistakable in a cyclone.
    var isEmphasised: Bool { self == .shelter }

    var label: LocalizedStringResource {
        switch self {
        case .beach: "poi.type.beach"
        case .airport: "poi.type.airport"
        case .landmark: "poi.type.landmark"
        case .viewpoint: "poi.type.viewpoint"
        case .hospital: "poi.type.hospital"
        case .fuel: "poi.type.fuel"
        case .restaurant: "poi.type.restaurant"
        case .hotel: "poi.type.hotel"
        case .market: "poi.type.market"
        case .park: "poi.type.park"
        case .other: "poi.type.other"
        case .shelter: "poi.type.shelter"
        case .clinic: "poi.type.clinic"
        case .pharmacy: "poi.type.pharmacy"
        case .police: "poi.type.police"
        case .supermarket: "poi.type.supermarket"
        case .mall: "poi.type.mall"
        case .waterfall: "poi.type.waterfall"
        case .hike: "poi.type.hike"
        case .ferry: "poi.type.ferry"
        case .marina: "poi.type.marina"
        case .helipad: "poi.type.helipad"
        case .town: "poi.type.town"
        }
    }
}
