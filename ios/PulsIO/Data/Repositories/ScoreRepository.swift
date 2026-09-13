import Foundation
import Supabase

protocol ScoreRepository: Sendable {
    func breakdown() async throws -> PulsScoreBreakdown?
}

struct SupabaseScoreRepository: ScoreRepository {
    let gateway: SupabaseGateway

    func breakdown() async throws -> PulsScoreBreakdown? {
        // The RPC returns a single jsonb object (null before the first score).
        try await gateway.client.rpc(PulsScoreBreakdown.rpc).execute().value
    }
}
