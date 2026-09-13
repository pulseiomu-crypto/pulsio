import Foundation
import Supabase

/// The pulse rules' API surface: read where the user stands, spend one. Nothing here decides anything.
protocol PulseRepository: Sendable {
    /// nil when signed out (the RPC returns no row).
    func status() async throws -> PulseStatus?
    /// The only argument the server ever receives is the district — never a coordinate (SPEC §10).
    func consume(district: District?) async throws(PulseFailure) -> PulseStatus
}

struct SupabasePulseRepository: PulseRepository {
    let gateway: SupabaseGateway

    func status() async throws -> PulseStatus? {
        let rows: [PulseStatus] = try await gateway.client.rpc(PulseStatus.statusRPC).execute().value
        return rows.first
    }

    func consume(district: District?) async throws(PulseFailure) -> PulseStatus {
        do {
            let rows: [PulseStatus] = try await gateway.client
                .rpc(PulseStatus.consumeRPC, params: ["p_district": district?.rawValue])
                .execute().value
            guard let row = rows.first else { throw PulseFailure.other("consume_pulse returned no row") }
            return row
        } catch let failure as PulseFailure {
            throw failure
        } catch let error as PostgrestError {
            // The rules raise `using detail = 'P-xxx'`; PostgREST surfaces that as `details`.
            if let detail = error.detail, let code = PulseCode(rawValue: detail) { throw .code(code) }
            throw .other(error.message)
        } catch {
            throw .other(String(describing: error))
        }
    }
}
