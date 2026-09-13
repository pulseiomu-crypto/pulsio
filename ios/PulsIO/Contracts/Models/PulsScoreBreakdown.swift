import Foundation

/// `pulsscore_breakdown()` — the latest PulsScore with its six components, each carrying how it was obtained.
/// Mirrors `pulsScoreComponent` / `pulsScoreVerdict` in `contracts/enums.json`.
struct PulsScoreBreakdown: Codable, Equatable, Sendable {
    static let rpc = "pulsscore_breakdown"

    enum Basis: String, Codable, Sendable {
        case measured, derived, placeholder
        init(from decoder: any Decoder) throws {
            self = Basis(rawValue: try decoder.singleValueContainer().decode(String.self)) ?? .placeholder
        }
    }

    struct Component: Codable, Equatable, Sendable, Identifiable {
        let key: String
        let weight: Int
        let score: Int
        let basis: Basis
        let tone: String
        var id: String { key }
    }

    let score: Int
    let calculatedAt: Date?
    let verdictKey: String
    let measuredCount: Int
    let componentCount: Int
    let components: [Component]

    var verdict: PulsScoreVerdict { PulsScoreVerdict(rawValue: verdictKey) ?? PulsScoreVerdict.band(for: score) }

    enum CodingKeys: String, CodingKey {
        case score, components
        case calculatedAt = "calculated_at"
        case verdictKey = "verdict_key"
        case measuredCount = "measured_count"
        case componentCount = "component_count"
    }
}

enum PulsScoreVerdict: String, Codable, CaseIterable, Sendable {
    case perfect, great, decent, challenging, difficult, severe

    static func band(for score: Int) -> PulsScoreVerdict {
        switch score {
        case 85...: .perfect
        case 70...: .great
        case 55...: .decent
        case 40...: .challenging
        case 25...: .difficult
        default: .severe
        }
    }

    var label: LocalizedStringResource {
        switch self {
        case .perfect: "pulsscore.verdict.perfect"
        case .great: "pulsscore.verdict.great"
        case .decent: "pulsscore.verdict.decent"
        case .challenging: "pulsscore.verdict.challenging"
        case .difficult: "pulsscore.verdict.difficult"
        case .severe: "pulsscore.verdict.severe"
        }
    }
}
