import SwiftUI

/// App shell. Navigation registration lives here (ARCHITECTURE §4): a new screen is one new `Features/`
/// module plus one entry in this file. The map is the root surface (FRONTEND §B); news and account open
/// as sheets from the top bar; the sign-in gate is an app-level sheet driven by `AccessGate`.
struct RootView: View {
    @Environment(SessionStore.self) private var session
    @Environment(AccessGate.self) private var gate
    @Environment(DistrictStore.self) private var districts
    @State private var isShowingAccount = false
    @State private var isShowingNews = false

    var body: some View {
        @Bindable var gate = gate
        NavigationStack {
            MapScreen()
                .toolbarBackground(.hidden, for: .navigationBar)
                .toolbar {
                    ToolbarItem(placement: .topBarLeading) {
                        Text(verbatim: "PulsIO")
                            .font(Typography.display(17, weight: .heavy))
                            .foregroundStyle(Palette.ink)
                            .fixedSize()
                            .padding(.horizontal, Metrics.Space.xs)
                            .accessibilityAddTraits(.isHeader)
                    }
                    ToolbarItem(placement: .topBarTrailing) {
                        Button { isShowingNews = true } label: {
                            Image(systemName: "newspaper")
                                .foregroundStyle(Palette.ink)
                        }
                        .accessibilityLabel(Text("news.title"))
                        .accessibilityIdentifier("root.news")
                    }
                    ToolbarItem(placement: .topBarTrailing) {
                        Button {
                            // FRONTEND §I: signed-out, the profile button opens sign-in rather than settings.
                            if session.isSignedIn { isShowingAccount = true } else { gate.presentSignIn() }
                        } label: {
                            Image(systemName: session.isSignedIn ? "person.crop.circle.fill" : "person.crop.circle")
                                .foregroundStyle(session.isSignedIn ? Palette.teal : Palette.ink)
                        }
                        .accessibilityLabel(Text("account.title"))
                        .accessibilityIdentifier("root.account")
                    }
                }
        }
        .sheet(isPresented: $isShowingNews) {
            NavigationStack { NewsFeedView() }
                .presentationDetents([.large])
                .presentationDragIndicator(.visible)
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
        .onChange(of: session.profile?.id) { _, _ in
            // Sign-in binds the device's district to the profile (or adopts the profile's).
            Task { await districts.reconcile(with: session.profile) }
        }
    }
}
