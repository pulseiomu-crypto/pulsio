/// Mirrors `reportCategory` in `contracts/enums.json` — the ten locked categories (SPEC §11).
enum ReportCategory: String, Codable, CaseIterable, Sendable, Identifiable {
    case powerCut = "power_cut", waterCut = "water_cut", accident, hazard, flood, traffic, jellyfish, event, infrastructure, other

    var id: String { rawValue }

    init(from decoder: any Decoder) throws {
        self = ReportCategory(rawValue: try decoder.singleValueContainer().decode(String.self)) ?? .other
    }
}

/// Mirrors `reportStatus`.
enum ReportStatus: String, Codable, CaseIterable, Sendable {
    case pending, unconfirmed, confirmed, hidden, removed, expired

    init(from decoder: any Decoder) throws {
        self = ReportStatus(rawValue: try decoder.singleValueContainer().decode(String.self)) ?? .pending
    }

    /// Visible on the map to everyone.
    var isLive: Bool { self == .unconfirmed || self == .confirmed }
}

/// Mirrors `reportModeration` numbers.
enum ReportRules {
    static let confirmRadiusMetres = 2_000.0
    static let flagsToHide = 2
    static let confirmationsToConfirm = 2
    static let expiryHours = 2
    static let descriptionLimit = 140
}
