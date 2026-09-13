import Foundation

/// One row of the `pulse_snapshot()` result — the server-assembled, server-ordered panel (ARCHITECTURE §6).
/// The client renders these generically: label and detail are localisation keys, values carry a unit code,
/// tone is a semantic colour token. Mirrors `panelRow` in `contracts/enums.json`.
struct PulsePanelRow: Codable, Identifiable, Hashable, Sendable {
    static let rpc = "pulse_snapshot"

    enum Kind: String, Codable, Sendable { case metric, status, count, list, computed }
    enum Value: Hashable, Sendable {
        case number(Double)
        case text(String)
    }

    let key: String
    let group: String
    let kind: Kind
    let labelKey: String
    var value: Value?
    let valueKey: String?
    let unit: String?
    let detailKey: String?
    let detailArgs: [String]
    let items: [String]
    let tone: String
    let tap: String?

    var id: String { key }

    enum CodingKeys: String, CodingKey {
        case key, group, kind, value, unit, items, tone, tap
        case labelKey = "label_key"
        case valueKey = "value_key"
        case detailKey = "detail_key"
        case detailArgs = "detail_args"
    }

    init(from decoder: any Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        key = try c.decode(String.self, forKey: .key)
        group = try c.decode(String.self, forKey: .group)
        kind = try c.decodeIfPresent(Kind.self, forKey: .kind) ?? .metric
        labelKey = try c.decode(String.self, forKey: .labelKey)
        if let n = try? c.decodeIfPresent(Double.self, forKey: .value) { value = .number(n) }
        else if let s = try? c.decodeIfPresent(String.self, forKey: .value) { value = .text(s) }
        else { value = nil }
        valueKey = try c.decodeIfPresent(String.self, forKey: .valueKey)
        unit = try c.decodeIfPresent(String.self, forKey: .unit)
        detailKey = try c.decodeIfPresent(String.self, forKey: .detailKey)
        // Args arrive as strings or numbers; both render as text.
        detailArgs = (try? c.decodeIfPresent([LenientString].self, forKey: .detailArgs))?.map(\.value) ?? []
        items = try c.decodeIfPresent([String].self, forKey: .items) ?? []
        tone = try c.decodeIfPresent(String.self, forKey: .tone) ?? "muted"
        tap = try c.decodeIfPresent(String.self, forKey: .tap)
    }

    func encode(to encoder: any Encoder) throws {
        var c = encoder.container(keyedBy: CodingKeys.self)
        try c.encode(key, forKey: .key); try c.encode(group, forKey: .group); try c.encode(kind, forKey: .kind)
        try c.encode(labelKey, forKey: .labelKey)
        switch value { case .number(let n)?: try c.encode(n, forKey: .value); case .text(let s)?: try c.encode(s, forKey: .value); case nil: break }
        try c.encodeIfPresent(valueKey, forKey: .valueKey); try c.encodeIfPresent(unit, forKey: .unit)
        try c.encodeIfPresent(detailKey, forKey: .detailKey); try c.encode(detailArgs, forKey: .detailArgs)
        try c.encode(items, forKey: .items); try c.encode(tone, forKey: .tone); try c.encodeIfPresent(tap, forKey: .tap)
    }
}

/// Decodes a JSON string or number as text.
struct LenientString: Codable, Hashable, Sendable {
    let value: String
    init(from decoder: any Decoder) throws {
        let c = try decoder.singleValueContainer()
        if let s = try? c.decode(String.self) { value = s }
        else if let d = try? c.decode(Double.self) { value = d == d.rounded() ? String(Int(d)) : String(d) }
        else { value = "" }
    }
    func encode(to encoder: any Encoder) throws { var c = encoder.singleValueContainer(); try c.encode(value) }
}

/// A weather station's location — for the on-device nearest-station pick (SPEC §14).
struct WeatherStation: Codable, Hashable, Sendable {
    static let rpc = "weather_stations"
    let station: String
    let lat: Double
    let lng: Double
}
