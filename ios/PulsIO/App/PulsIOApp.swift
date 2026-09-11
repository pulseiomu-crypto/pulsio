import SwiftUI

@main
struct PulsIOApp: App {
    private let environment = AppEnvironment.live()

    var body: some Scene {
        WindowGroup {
            RootView()
                .environment(\.newsRepository, environment.news)
                .environment(environment.session)
                .environment(environment.gate)
                .preferredColorScheme(.dark)
                .tint(Palette.teal)
                .task { environment.session.start() }
                .onOpenURL { url in
                    Task { await environment.session.handle(url: url) }
                }
        }
    }
}
