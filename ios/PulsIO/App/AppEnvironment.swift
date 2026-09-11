import Foundation

/// Composition root: the one place that knows which concrete repositories the app runs on.
/// Features only ever see protocols from `Data/`, injected through the SwiftUI environment.
struct AppEnvironment {
    let news: any NewsRepository

    static func live() -> AppEnvironment {
        let config: SupabaseConfig
        do {
            config = try SupabaseConfig.fromBundle()
        } catch {
            // A missing key is a build-configuration defect, not a runtime condition — fail at launch, loudly.
            fatalError("PulsIO cannot start: \(error.localizedDescription)")
        }
        let gateway = SupabaseGateway(config: config)
        return AppEnvironment(news: SupabaseNewsRepository(gateway: gateway))
    }
}
