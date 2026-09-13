import Foundation
import Observation

/// The latest PulsScore breakdown. Public-read; refreshed on launch, foreground and after each pulse.
@MainActor
@Observable
final class ScoreStore {
    private(set) var breakdown: PulsScoreBreakdown?
    private(set) var lastError: String?

    private let scores: any ScoreRepository

    init(scores: any ScoreRepository) {
        self.scores = scores
    }

    func refresh() async {
        do { breakdown = try await scores.breakdown() } catch { lastError = String(describing: error) }
    }
}
