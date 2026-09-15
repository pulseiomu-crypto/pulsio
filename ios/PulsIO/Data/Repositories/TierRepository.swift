import Foundation
import Supabase

protocol TierRepository: Sendable {
    func rules() async throws -> [TierRule]
}

struct SupabaseTierRepository: TierRepository {
    let gateway: SupabaseGateway
    func rules() async throws -> [TierRule] {
        try await gateway.client.from(TierRule.table).select().order("sort_order").execute().value
    }
}

import SwiftUI

private struct TierRepositoryKey: EnvironmentKey {
    struct Unconfigured: TierRepository { func rules() async throws -> [TierRule] { [] } }
    static let defaultValue: any TierRepository = Unconfigured()
}

extension EnvironmentValues {
    var tierRepository: any TierRepository {
        get { self[TierRepositoryKey.self] }
        set { self[TierRepositoryKey.self] = newValue }
    }
}
