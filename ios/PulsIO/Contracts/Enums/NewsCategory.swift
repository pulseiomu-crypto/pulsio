import Foundation

/// Mirrors `newsCategory` in `contracts/enums.json` (ARCHITECTURE §3, kind 2).
/// Until codegen exists, edit the JSON and this file together. Unknown values decode to `.general`
/// so a new category added upstream never breaks the feed.
enum NewsCategory: String, Codable, CaseIterable, Sendable {
    case breaking
    case crime
    case traffic
    case weather
    case community
    case politics
    case economy
    case sports
    case tourism
    case general

    init(from decoder: any Decoder) throws {
        let raw = try decoder.singleValueContainer().decode(String.self)
        self = NewsCategory(rawValue: raw) ?? .general
    }
}
