import Foundation
import SwiftUI

/// What the News feature is allowed to ask for. Features depend on this protocol, never on Supabase types.
protocol NewsRepository: Sendable {
    /// Latest articles, newest first (FRONTEND §F: ordered by `published_at`, limit 50).
    func latest(limit: Int) async throws -> [NewsArticle]
}

struct SupabaseNewsRepository: NewsRepository {
    let gateway: SupabaseGateway

    func latest(limit: Int) async throws -> [NewsArticle] {
        try await gateway.client
            .from(NewsArticle.table)
            .select()
            .order("published_at", ascending: false, nullsFirst: false)
            .limit(limit)
            .execute()
            .value
    }
}

// MARK: - Environment injection

/// Repositories reach features through the SwiftUI environment. A feature reads the one it needs;
/// the composition root in `App/` decides which implementation is behind it.
private struct NewsRepositoryKey: EnvironmentKey {
    static let defaultValue: any NewsRepository = UnconfiguredNewsRepository()
}

extension EnvironmentValues {
    var newsRepository: any NewsRepository {
        get { self[NewsRepositoryKey.self] }
        set { self[NewsRepositoryKey.self] = newValue }
    }
}

/// Loud default so a feature rendered outside the composition root fails visibly rather than silently.
private struct UnconfiguredNewsRepository: NewsRepository {
    struct NotConfigured: Error {}
    func latest(limit: Int) async throws -> [NewsArticle] { throw NotConfigured() }
}
