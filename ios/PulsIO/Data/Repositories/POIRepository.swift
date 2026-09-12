import Foundation
import Supabase

/// Remote side of POI sync: the `poi_changes_since` / `poi_version` RPCs.
protocol POIRepository: Sendable {
    func changes(since version: Int64, limit: Int) async throws -> [POIChange]
    func currentVersion() async throws -> Int64
}

struct SupabasePOIRepository: POIRepository {
    let gateway: SupabaseGateway

    func changes(since version: Int64, limit: Int) async throws -> [POIChange] {
        try await gateway.client
            .rpc(POIChange.rpc, params: ["p_since": version, "p_limit": Int64(limit)])
            .execute()
            .value
    }

    func currentVersion() async throws -> Int64 {
        try await gateway.client.rpc(POIChange.versionRPC).execute().value
    }
}
