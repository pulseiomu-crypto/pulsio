import Foundation

/// One row of `pulsio_profiles` — the app-side account record, keyed by the auth user id.
/// Hand-written against the schema, every column listed (ARCHITECTURE §3). Created server-side by the
/// `on_auth_user_created` trigger on first sign-in, with the schema's free-tier defaults.
struct Profile: Codable, Identifiable, Hashable, Sendable {
    static let table = "pulsio_profiles"

    let id: UUID
    var displayName: String?
    var userType: UserType
    var district: District?
    var tier: Tier
    var pulsesRemaining: Int
    var pulsesTotal: Int
    var pulseTopupBalance: Int
    var morningPulseTime: String
    var morningPulseEnabled: Bool
    var language: AppLanguage
    var priorities: [String]
    var deviceCount: Int
    var referralHotel: String?
    let createdAt: Date?
    let updatedAt: Date?

    enum CodingKeys: String, CodingKey {
        case id
        case displayName = "display_name"
        case userType = "user_type"
        case district
        case tier
        case pulsesRemaining = "pulses_remaining"
        case pulsesTotal = "pulses_total"
        case pulseTopupBalance = "pulse_topup_balance"
        case morningPulseTime = "morning_pulse_time"
        case morningPulseEnabled = "morning_pulse_enabled"
        case language
        case priorities
        case deviceCount = "device_count"
        case referralHotel = "referral_hotel"
        case createdAt = "created_at"
        case updatedAt = "updated_at"
    }

    init(from decoder: any Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = try c.decode(UUID.self, forKey: .id)
        displayName = try c.decodeIfPresent(String.self, forKey: .displayName)
        // Nullable columns with DB defaults: decode leniently so a stray NULL never breaks sign-in.
        userType = try c.decodeIfPresent(UserType.self, forKey: .userType) ?? .mauritian
        district = try c.decodeIfPresent(String.self, forKey: .district).flatMap(District.init(rawValue:))
        tier = try c.decodeIfPresent(Tier.self, forKey: .tier) ?? .free
        pulsesRemaining = try c.decodeIfPresent(Int.self, forKey: .pulsesRemaining) ?? 0
        pulsesTotal = try c.decodeIfPresent(Int.self, forKey: .pulsesTotal) ?? 0
        pulseTopupBalance = try c.decodeIfPresent(Int.self, forKey: .pulseTopupBalance) ?? 0
        morningPulseTime = try c.decodeIfPresent(String.self, forKey: .morningPulseTime) ?? "07:00"
        morningPulseEnabled = try c.decodeIfPresent(Bool.self, forKey: .morningPulseEnabled) ?? false
        language = try c.decodeIfPresent(AppLanguage.self, forKey: .language) ?? .en
        priorities = try c.decodeIfPresent([String].self, forKey: .priorities) ?? []
        deviceCount = try c.decodeIfPresent(Int.self, forKey: .deviceCount) ?? 0
        referralHotel = try c.decodeIfPresent(String.self, forKey: .referralHotel)
        createdAt = try c.decodeIfPresent(Date.self, forKey: .createdAt)
        updatedAt = try c.decodeIfPresent(Date.self, forKey: .updatedAt)
    }
}
