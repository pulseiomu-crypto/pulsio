import SwiftUI

/// App shell. Navigation registration lives here (ARCHITECTURE §4): a new screen is one new `Features/`
/// module plus one entry in this file. The shell is a single stack around the news feed until the map lands;
/// it also hosts the two app-level sheets — sign-in (from `AccessGate`) and account.
struct RootView: View {
    @Environment(SessionStore.self) private var session
    @Environment(AccessGate.self) private var gate
    @State private var isShowingAccount = false

    var body: some View {
        @Bindable var gate = gate
        NavigationStack {
            NewsFeedView()
                .toolbar {
                    ToolbarItem(placement: .topBarTrailing) {
                        Button {
                            // FRONTEND §I: signed-out, the profile button opens sign-in rather than settings.
                            if session.isSignedIn { isShowingAccount = true } else { gate.presentSignIn() }
                        } label: {
                            Image(systemName: session.isSignedIn ? "person.crop.circle.fill" : "person.crop.circle")
                                .foregroundStyle(session.isSignedIn ? Palette.teal : Palette.muted)
                        }
                        .accessibilityLabel(Text("account.title"))
                        .accessibilityIdentifier("root.account")
                    }
                }
        }
        .sheet(isPresented: $gate.isPresentingSignIn, onDismiss: { gate.cancel() }) {
            SignInSheet()
        }
        .sheet(isPresented: $isShowingAccount) {
            AccountView()
        }
        .onChange(of: session.isSignedIn) { _, signedIn in
            if signedIn { gate.sessionDidSignIn() } else { isShowingAccount = false }
        }
    }
}
