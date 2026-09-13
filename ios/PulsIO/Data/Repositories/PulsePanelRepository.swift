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
        struct Params: Encodable { let p_district: String?; let p_station: String?; let p_priorities: [String] }
        return try await gateway.client
            .rpc(PulsePanelRow.rpc, params: Params(p_district: district?.rawValue, p_station: station, p_priorities: priorities))
            .execute().value
    }

    func stations() async throws -> [WeatherStation] {
        try await gateway.client.rpc(WeatherStation.rpc).execute().value
    }
}
