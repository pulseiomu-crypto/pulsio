import Foundation
import Observation

/// State for the news feed. Talks to `NewsRepository`, nothing else.
@MainActor
@Observable
final class NewsFeedViewModel {
    enum Phase: Equatable {
        case idle
        case loading
        case loaded
        case failed
    }

    private(set) var articles: [NewsArticle] = []
    private(set) var phase: Phase = .idle
    private(set) var lastError: String?

    private let repository: any NewsRepository
    private let pageSize: Int

    init(repository: any NewsRepository, pageSize: Int = 50) {
        self.repository = repository
        self.pageSize = pageSize
    }

    /// First load: shows the loading state. Subsequent calls keep existing rows on screen while refreshing.
    func load() async {
        if articles.isEmpty { phase = .loading }
        do {
            articles = try await repository.latest(limit: pageSize)
            lastError = nil
            phase = .loaded
        } catch {
            lastError = String(describing: error)
            // Keep stale rows visible if we have them; only surface the failure state on an empty feed.
            phase = articles.isEmpty ? .failed : .loaded
        }
    }
}
