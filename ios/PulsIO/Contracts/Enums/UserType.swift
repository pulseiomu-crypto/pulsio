/// Mirrors `userType` in `contracts/enums.json` (onboarding step 3, FRONTEND §C).
enum UserType: String, Codable, CaseIterable, Sendable {
    case mauritian, tourist, pro

    init(from decoder: any Decoder) throws {
        self = UserType(rawValue: try decoder.singleValueContainer().decode(String.self)) ?? .mauritian
    }
}
