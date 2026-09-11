import Foundation
import Testing
@testable import PulsIO

/// The row model is hand-written against the `pulsio_news` schema (ARCHITECTURE §3); these pin its
/// decoding rules so a schema or SDK change shows up here before it shows up as an empty feed.
struct NewsArticleDecodingTests {
    private func decode(_ json: String) throws -> NewsArticle {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return try decoder.decode(NewsArticle.self, from: Data(json.utf8))
    }

    @Test func decodesAFullRow() throws {
        let row = try decode("""
        {"id": 42, "headline": "Cyclone watch lifted", "summary": "MMS says all clear.", "source": "Defimedia",
         "source_url": "https://defimedia.info/x", "category": "weather", "image_url": null,
         "lat": -20.16, "lng": 57.5, "published_at": "2026-09-05T10:22:00Z", "fetched_at": "2026-09-05T10:30:00Z"}
        """)
        #expect(row.id == 42)
        #expect(row.headline == "Cyclone watch lifted")
        #expect(row.category == .weather)
        #expect(row.sourceURL?.host() == "defimedia.info")
        #expect(row.imageURL == nil)
        #expect(row.lat == -20.16)
        #expect(row.publishedAt != nil)
    }

    @Test func unknownCategoryFallsBackToGeneral() throws {
        let row = try decode("""
        {"id": 1, "headline": "h", "source": "s", "category": "astrology"}
        """)
        #expect(row.category == .general)
    }

    @Test func nullCategoryFallsBackToGeneral() throws {
        let row = try decode("""
        {"id": 1, "headline": "h", "source": "s", "category": null}
        """)
        #expect(row.category == .general)
    }

    @Test(arguments: ["", "not a url at all ^^", "javascript:alert(1)", "ftp://x.y/z", "/relative/path", "mailto:a@b.c"])
    func nonWebURLIsDroppedWithoutFailingTheRow(raw: String) throws {
        let row = try decode("""
        {"id": 1, "headline": "h", "source": "s", "source_url": "\(raw)", "image_url": "\(raw)"}
        """)
        #expect(row.sourceURL == nil)
        #expect(row.imageURL == nil)
    }
}
