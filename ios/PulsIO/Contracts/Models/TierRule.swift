import Foundation

/// One row of `pulsio_tier_rules` — tier → limits (ARCHITECTURE §2: tier rules are data, read by every client).
struct TierRule: Codable, Hashable, Sendable, Identifiable {
    static let table = "pulsio_tier_rules"
    let tier: Tier
    let displayName: String
    /// nil = unlimited
    let pulsesPerDay: Int?
    let ads: Bool
    let deviceMax: Int
    let sortOrder: Int
    var id: String { tier.rawValue }

    enum CodingKeys: String, CodingKey {
        case tier, ads
        case displayName = "display_name"
        case pulsesPerDay = "pulses_per_day"
        case deviceMax = "device_max"
        case sortOrder = "sort_order"
    }
}
