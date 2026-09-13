import Foundation
import Testing
@testable import PulsIO

/// Paging through the change feed until caught up, resuming from the stored high-water mark.
struct POISyncTests {
    /// Serves a fixed change log; records every `since` it was asked for.
    final class FakeRemote: POIRepository, @unchecked Sendable {
        let log: [POIChange]
        var requests: [Int64] = []
        init(log: [POIChange]) { self.log = log }
        func changes(since version: Int64, limit: Int) async throws -> [POIChange] {
            requests.append(version)
            return Array(log.filter { $0.version > version }.prefix(limit))
        }
        func currentVersion() async throws -> Int64 { log.map(\.version).max() ?? 0 }
    }

    private func row(_ id: Int64, _ version: Int64) -> POIChange {
        POIChange(id: id, version: version, deleted: false, type: .beach, name: "b\(id)", lat: -20.2, lng: 57.5, district: nil,
                  phone: nil, hours: nil, description: nil, rating: nil, seg: ["all"], active: true, locationPrecision: .exact, updatedAt: nil)
    }

    @Test @MainActor func pagesUntilCaughtUpThenResumesIncrementally() async throws {
        let store = try POIStore.inMemory()
        let remote = FakeRemote(log: (1...7).map { row($0, Int64($0) * 10) })
        let sync = POISync(remote: remote, store: store, pageSize: 3)

        await sync.run()
        #expect(sync.phase == .idle)
        #expect(sync.lastApplied == 7)
        #expect(remote.requests == [0, 30, 60])           // 3 + 3 + 1 rows; the short page ends the run
        #expect(try await store.highWaterVersion() == 70)

        await sync.run()                                  // nothing new: one request, nothing applied
        #expect(remote.requests.last == 70)
        #expect(sync.lastApplied == 0)
    }

    @Test @MainActor func failureIsReportedNotSwallowed() async throws {
        struct Boom: Error {}
        struct Failing: POIRepository {
            func changes(since version: Int64, limit: Int) async throws -> [POIChange] { throw Boom() }
            func currentVersion() async throws -> Int64 { 0 }
        }
        let sync = POISync(remote: Failing(), store: try POIStore.inMemory())
        await sync.run()
        guard case .failed = sync.phase else { Issue.record("expected .failed, got \(sync.phase)"); return }
    }
}
