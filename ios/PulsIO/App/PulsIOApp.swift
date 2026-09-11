import SwiftUI

@main
struct PulsIOApp: App {
    private let environment = AppEnvironment.live()

    var body: some Scene {
        WindowGroup {
            RootView()
                .environment(\.newsRepository, environment.news)
                .preferredColorScheme(.dark)
                .tint(Palette.teal)
        }
    }
}
