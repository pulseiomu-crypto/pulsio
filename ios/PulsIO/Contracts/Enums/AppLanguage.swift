/// Mirrors `language` in `contracts/enums.json`. `cr` survives in the DB CHECK but is never offered (SPEC §22).
enum AppLanguage: String, Codable, CaseIterable, Sendable {
    case en, fr, cr

    init(from decoder: any Decoder) throws {
        self = AppLanguage(rawValue: try decoder.singleValueContainer().decode(String.self)) ?? .en
    }
}
