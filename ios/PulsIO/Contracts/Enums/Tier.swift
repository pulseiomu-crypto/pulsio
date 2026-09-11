/// Mirrors `tier` in `contracts/enums.json`. Tier *rules* (pulses/day, ads, features) will come from
/// Supabase (ARCHITECTURE §2) — this is only the identifier.
enum Tier: String, Codable, CaseIterable, Sendable {
    case free, t1, t2, pro

    init(from decoder: any Decoder) throws {
        self = Tier(rawValue: try decoder.singleValueContainer().decode(String.self)) ?? .free
    }
}
