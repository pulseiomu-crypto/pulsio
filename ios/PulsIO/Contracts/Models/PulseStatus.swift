import Foundation

/// One row of `pulse_status()` / `consume_pulse()` — where the caller stands with today's quota
/// (ARCHITECTURE §2: the rule lives in Supabase; this is only its answer).
struct PulseStatus: Codable, Equatable, Sendable {
    static let statusRPC = "pulse_status"
    static let consumeRPC = "consume_pulse"

    /// `quota` or `topup` — what paid for the pulse just fired. Only on `consume_pulse` rows.
    let paidFrom: String?
    let tier: Tier
    let tierName: String
    /// nil = unlimited.
    let pulsesPerDay: Int?
    let usedToday: Int
    /// nil = unlimited.
    let quotaRemaining: Int?
    let topupBalance: Int
    /// The coming Mauritius midnight.
    let nextResetAt: Date
    let canPulse: Bool

    var isUnlimited: Bool { pulsesPerDay == nil }
    /// Pulses that can still be fired today from any source; nil = unlimited.
    var available: Int? { isUnlimited ? nil : (quotaRemaining ?? 0) + topupBalance }

    enum CodingKeys: String, CodingKey {
        case paidFrom = "paid_from"
        case tier
        case tierName = "tier_name"
        case pulsesPerDay = "pulses_per_day"
        case usedToday = "used_today"
        case quotaRemaining = "quota_remaining"
        case topupBalance = "topup_balance"
        case nextResetAt = "next_reset_at"
        case canPulse = "can_pulse"
    }
}

/// Mirrors `contracts/errors.json` (the P-codes the pulse rules can raise).
enum PulseCode: String, Sendable {
    case signIn = "P-100"
    case noProfile = "P-101"
    case spent = "P-103"

    var messageKey: LocalizedStringResource {
        switch self {
        case .signIn: "pulse.error.signIn"
        case .noProfile: "pulse.error.noProfile"
        case .spent: "pulse.error.spent"
        }
    }
}

enum PulseFailure: Error, Equatable {
    case code(PulseCode)
    case other(String)
}
