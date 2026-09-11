import Foundation

/// One row of `pulsio_news`.
///
/// Hand-written row model (ARCHITECTURE §3, kind 1): the Postgres schema is the source of truth and this
/// struct mirrors it column-for-column. Every column is listed — including ones the UI doesn't use yet —
/// so the schema-coverage CI gate has something honest to diff against.
struct NewsArticle: Codable, Identifiable, Hashable, Sendable {
    static let table = "pulsio_news"

    let id: Int64
    let headline: String
    let summary: String?
    let source: String
    let sourceURL: URL?
    let category: NewsCategory
    let imageURL: URL?
    let lat: Double?
    let lng: Double?
    let publishedAt: Date?
    let fetchedAt: Date?

    enum CodingKeys: String, CodingKey {
        case id
        case headline
        case summary
        case source
        case sourceURL = "source_url"
        case category
        case imageURL = "image_url"
        case lat
        case lng
        case publishedAt = "published_at"
        case fetchedAt = "fetched_at"
    }

    init(from decoder: any Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = try c.decode(Int64.self, forKey: .id)
        headline = try c.decode(String.self, forKey: .headline)
        summary = try c.decodeIfPresent(String.self, forKey: .summary)
        source = try c.decode(String.self, forKey: .source)
        // Feed content is external: a bad URL must not fail the whole row, and only web URLs are honoured
        // (iOS 17+ `URL(string:)` is lenient, so "is it a URL" alone doesn't protect `Link`).
        sourceURL = try c.decodeIfPresent(String.self, forKey: .sourceURL).flatMap(Self.webURL)
        category = try c.decodeIfPresent(NewsCategory.self, forKey: .category) ?? .general
        imageURL = try c.decodeIfPresent(String.self, forKey: .imageURL).flatMap(Self.webURL)
        lat = try c.decodeIfPresent(Double.self, forKey: .lat)
        lng = try c.decodeIfPresent(Double.self, forKey: .lng)
        publishedAt = try c.decodeIfPresent(Date.self, forKey: .publishedAt)
        fetchedAt = try c.decodeIfPresent(Date.self, forKey: .fetchedAt)
    }

    /// `http(s)` URLs only; anything else (empty, relative, `javascript:`, custom schemes) is dropped.
    static func webURL(_ raw: String) -> URL? {
        guard let url = URL(string: raw), let scheme = url.scheme?.lowercased(),
              scheme == "http" || scheme == "https", url.host() != nil else { return nil }
        return url
    }

    init(
        id: Int64, headline: String, summary: String?, source: String, sourceURL: URL?,
        category: NewsCategory, imageURL: URL?, lat: Double?, lng: Double?, publishedAt: Date?, fetchedAt: Date?
    ) {
        self.id = id
        self.headline = headline
        self.summary = summary
        self.source = source
        self.sourceURL = sourceURL
        self.category = category
        self.imageURL = imageURL
        self.lat = lat
        self.lng = lng
        self.publishedAt = publishedAt
        self.fetchedAt = fetchedAt
    }
}
