import Foundation

/// Mirrors `district` in `contracts/enums.json` — SPEC §10: the app's only location state, one of nine
/// values. Raw values are spelled exactly as the pipeline writes `pulsio_ceb.district` etc., so they join.
/// The server never sees anything finer than one of these.
enum District: String, Codable, CaseIterable, Sendable, Identifiable {
    case portLouis = "Port Louis"
    case pamplemousses = "Pamplemousses"
    case riviereDuRempart = "Rivière du Rempart"
    case flacq = "Flacq"
    case grandPort = "Grand Port"
    case savanne = "Savanne"
    case plainesWilhems = "Plaines Wilhems"
    case moka = "Moka"
    case blackRiver = "Black River"

    var id: String { rawValue }

    var label: LocalizedStringResource {
        switch self {
        case .portLouis: "district.portLouis"
        case .pamplemousses: "district.pamplemousses"
        case .riviereDuRempart: "district.riviereDuRempart"
        case .flacq: "district.flacq"
        case .grandPort: "district.grandPort"
        case .savanne: "district.savanne"
        case .plainesWilhems: "district.plainesWilhems"
        case .moka: "district.moka"
        case .blackRiver: "district.blackRiver"
        }
    }
}
