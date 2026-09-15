import SwiftUI

@main
struct PulsIOApp: App {
    @Environment(\.scenePhase) private var scenePhase
    private let environment = AppEnvironment.live()

    var body: some Scene {
        WindowGroup {
            RootView()
                .environment(\.newsRepository, environment.news)
                .environment(\.poiStore, environment.poiStore)
                .environment(\.tierRepository, environment.tiers)
                .environment(environment.poiSync)
                .environment(environment.session)
                .environment(environment.gate)
                .environment(environment.districts)
                .environment(environment.preferences)
                .environment(environment.pulses)
                .environment(environment.pulseFX)
                .environment(environment.pulseResult)
                .environment(environment.scores)
                .environment(environment.reports)
                .preferredColorScheme(.dark)
                .tint(Palette.teal)
                .task { environment.session.start() }
                .onOpenURL { url in
                    Task { await environment.session.handle(url: url) }
                }
                .onChange(of: scenePhase) { _, phase in
                    // Reference data refresh on foreground (ARCHITECTURE §8: pull deltas on launch/foreground).
                    if phase == .active { Task { await environment.poiSync.run(); await environment.scores.refresh() } }
                }
        }
    }
}
