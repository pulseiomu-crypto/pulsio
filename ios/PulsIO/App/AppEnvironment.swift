import Foundation

/// Composition root: the one place that knows which concrete repositories and stores the app runs on.
/// Features only ever see protocols from `Data/` (via the environment) and the app-level stores.
@MainActor
struct AppEnvironment {
    let news: any NewsRepository
    let session: SessionStore
    let gate: AccessGate
    let poiStore: POIStore
    let poiSync: POISync

    static func live() -> AppEnvironment {
        let config: SupabaseConfig
        let poiStore: POIStore
        do {
            config = try SupabaseConfig.fromBundle()
            poiStore = try POIStore.onDisk()
        } catch {
            // Missing config or an unopenable local database are build/install defects — fail at launch, loudly.
            fatalError("PulsIO cannot start: \(error)")
        }
        let gateway = SupabaseGateway(config: config)
        let session = SessionStore(
            auth: SupabaseAuthRepository(gateway: gateway),
            profiles: SupabaseProfileRepository(gateway: gateway),
            emergencies: SupabaseEmergencyRepository(gateway: gateway)
        )
        return AppEnvironment(
            news: SupabaseNewsRepository(gateway: gateway),
            session: session,
            gate: AccessGate(session: session),
            poiStore: poiStore,
            poiSync: POISync(remote: SupabasePOIRepository(gateway: gateway), store: poiStore)
        )
    }
}
