import Foundation
import Observation

/// Pulls POI deltas from the server into the device store, page by page, until caught up. Safe to call
/// repeatedly (launch, foreground, pull-to-refresh); concurrent calls collapse into one run.
@MainActor
@Observable
final class POISync {
    enum Phase: Equatable {
        case idle
        case syncing
        case failed(String)
    }

    private(set) var phase: Phase = .idle
    private(set) var lastRun: Date?
    /// Rows applied in the last run — useful for "N places updated" and for tests.
    private(set) var lastApplied = 0

    private let remote: any POIRepository
    private let store: POIStore
    private let pageSize: Int
    private var running: Task<Void, Never>?

    init(remote: any POIRepository, store: POIStore, pageSize: Int = 500) {
        self.remote = remote
        self.store = store
        self.pageSize = pageSize
    }

    /// Returns when the store is caught up (or the run failed). Joins an in-flight run rather than starting another.
    func run() async {
        if let running {
            await running.value
            return
        }
        let task = Task { await performRun() }
        running = task
        await task.value
        running = nil
    }

    private func performRun() async {
        phase = .syncing
        var applied = 0
        do {
            var since = try await store.highWaterVersion()
            while true {
                let page = try await remote.changes(since: since, limit: pageSize)
                if page.isEmpty { break }
                let result = try await store.apply(page)
                applied += result.upserted + result.deleted
                since = result.highWater
                if page.count < pageSize { break }
            }
            lastApplied = applied
            lastRun = .now
            phase = .idle
        } catch {
            phase = .failed(String(describing: error))
        }
    }
}
