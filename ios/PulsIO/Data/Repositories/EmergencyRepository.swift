import Foundation
import Supabase

/// Reads the `pulsio_emergency_state` view. Public-read: the emergency exception must work signed-out.
protocol EmergencyRepository: Sendable {
    func current() async throws -> EmergencyState
}

struct SupabaseEmergencyRepository: EmergencyRepository {
    let gateway: SupabaseGateway

    func current() async throws -> EmergencyState {
        let rows: [EmergencyState] = try await gateway.client
            .from(EmergencyState.view).select().limit(1).execute().value
        return rows.first ?? .none
    }
}
