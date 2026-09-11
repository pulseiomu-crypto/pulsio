import SwiftUI

/// App shell. Navigation registration lives here (ARCHITECTURE §4): a new screen is one new `Features/`
/// module plus one entry in this file. For this first pass the shell is a single stack around the news feed;
/// the adaptive iPhone/iPad layout (FRONTEND §1) replaces it when the map lands.
struct RootView: View {
    var body: some View {
        NavigationStack {
            NewsFeedView()
        }
    }
}
