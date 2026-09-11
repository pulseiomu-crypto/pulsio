import Foundation

/// Composition root: the one place that knows which concrete repositories the app runs on.
/// Features only ever see protocols from `Data/` (via the environment) and the app-level stores.
@MainActor
struct AppEnvironment {
    let news: any NewsRepository
    let session: SessionStore
    let gate: AccessGate

    static func live() -> AppEnvironment {
        let config: SupabaseConfig
        do {
            config = try SupabaseConfig.fromBundle()
        } catch {
            // A missing key is a build-configuration defect, not a runtime condition — fail at launch, loudly.
            fatalError("PulsIO cannot start: \(error.localizedDescription)")
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
            gate: AccessGate(session: session)
        )
    }
}
