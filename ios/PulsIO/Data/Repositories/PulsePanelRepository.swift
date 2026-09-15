import Foundation
import Supabase

/// The panel's API surface: the assembled snapshot, and the station list the device picks the nearest from.
protocol PulsePanelRepository: Sendable {
    func snapshot(district: District?, station: String?, priorities: [String]) async throws -> [PulsePanelRow]
    func stations() async throws -> [WeatherStation]
}

struct SupabasePulsePanelRepository: PulsePanelRepository {
    let gateway: SupabaseGateway

    func snapshot(district: District?, station: String?, priorities: [String]) async throws -> [PulsePanelRow] {
        // Explicit nulls: an omitted key would change the RPC signature PostgREST looks for.
        let params: [String: AnyJSON] = [
            "p_district": district.map { AnyJSON.string($0.rawValue) } ?? .null,
            "p_station": station.map(AnyJSON.string) ?? .null,
            "p_priorities": .array(priorities.map(AnyJSON.string)),
        ]
        return try await gateway.client.rpc(PulsePanelRow.rpc, params: params).execute().value
    }

    func stations() async throws -> [WeatherStation] {
        try await gateway.client.rpc(WeatherStation.rpc).execute().value
    }
}
