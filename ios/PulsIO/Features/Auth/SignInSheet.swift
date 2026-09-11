import AuthenticationServices
import SwiftUI

/// The gate itself: says what an account unlocks, offers the three doors. Never a dead end — Cancel always
/// returns to browsing. Presented by `RootView` when `AccessGate` asks for it.
struct SignInSheet: View {
    @Environment(SessionStore.self) private var session
    @Environment(AccessGate.self) private var gate
    @Environment(\.dismiss) private var dismiss
    @State private var model: SignInViewModel?
    @State private var nonce = AppleSignInNonce()

    var body: some View {
        NavigationStack {
            Group {
                if let model {
                    content(model)
                } else {
                    Color.clear
                }
            }
            .background(Palette.abyss.ignoresSafeArea())
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button { gate.cancel(); dismiss() } label: { Text("common.cancel") }
                        .accessibilityIdentifier("signin.cancel")
                }
            }
        }
        .onAppear { if model == nil { model = SignInViewModel(session: session) } }
        .presentationDetents([.large])
        .presentationDragIndicator(.visible)
    }

    @ViewBuilder
    private func content(_ model: SignInViewModel) -> some View {
        @Bindable var model = model
        ScrollView {
            VStack(alignment: .leading, spacing: Metrics.Space.xl) {
                VStack(alignment: .leading, spacing: Metrics.Space.sm) {
                    Eyebrow(text: "auth.eyebrow", tint: Palette.teal)
                    Text(title)
                        .font(Typography.display(26))
                        .foregroundStyle(Palette.ink)
                        .fixedSize(horizontal: false, vertical: true)
                }

                VStack(alignment: .leading, spacing: Metrics.Space.md) {
                    benefit("bolt.fill", "auth.benefit.pulse")
                    benefit("exclamationmark.bubble.fill", "auth.benefit.report")
                    benefit("arrow.triangle.2.circlepath", "auth.benefit.sync")
                    benefit("star.fill", "auth.benefit.subscribe")
                }

                Text("auth.freeNote")
                    .font(Typography.body(13))
                    .foregroundStyle(Palette.muted)
                    .fixedSize(horizontal: false, vertical: true)

                Rectangle().fill(Palette.hair).frame(height: Metrics.hairline)

                switch model.phase {
                case .linkSent(let address):
                    linkSent(model, address: address)
                case .idle, .working:
                    doors(model)
                }

                if let key = model.errorKey {
                    Text(LocalizedStringResource(stringLiteral: key))
                        .font(Typography.mono(11))
                        .foregroundStyle(Palette.coral)
                        .fixedSize(horizontal: false, vertical: true)
                        .accessibilityIdentifier("signin.error")
                }

                Text("auth.noPasswords")
                    .font(Typography.mono(10))
                    .foregroundStyle(Palette.muted2)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .padding(Metrics.Space.lg)
            .frame(maxWidth: 560, alignment: .leading)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .scrollDismissesKeyboard(.interactively)
        .disabled(model.isWorking)
        .overlay {
            if model.isWorking {
                ProgressView { Text("auth.working") }
                    .font(Typography.mono(11))
                    .tint(Palette.teal)
                    .padding(Metrics.Space.xl)
                    .background(Palette.deep, in: RoundedRectangle(cornerRadius: Metrics.Radius.md, style: .continuous))
            }
        }
    }

    private var title: LocalizedStringResource {
        switch gate.reason {
        case .firePulse: "auth.title.firePulse"
        case .submitReport: "auth.title.submitReport"
        case .confirmReport: "auth.title.confirmReport"
        case .saveToProfile: "auth.title.saveToProfile"
        case .subscribe: "auth.title.subscribe"
        case .viewCycloneAlerts: "auth.title.viewCycloneAlerts"
        case .viewShelters: "auth.title.viewShelters"
        case nil: "auth.title.generic"
        }
    }

    private func benefit(_ symbol: String, _ key: LocalizedStringResource) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: Metrics.Space.md) {
            Image(systemName: symbol)
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(Palette.teal)
                .frame(width: 16)
            Text(key)
                .font(Typography.body(14))
                .foregroundStyle(Palette.ink)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    @ViewBuilder
    private func doors(_ model: SignInViewModel) -> some View {
        @Bindable var model = model
        VStack(spacing: Metrics.Space.md) {
            SignInWithAppleButton(.continue) { request in
                request.requestedScopes = [.fullName, .email]
                request.nonce = nonce.hashed
            } onCompletion: { result in
                handleApple(result, model: model)
            }
            .signInWithAppleButtonStyle(.white)
            .frame(height: 48)
            .clipShape(RoundedRectangle(cornerRadius: Metrics.Radius.sm, style: .continuous))
            .accessibilityIdentifier("signin.apple")

            Button {
                Task { await model.signInWithGoogle() }
            } label: {
                Label { Text("auth.google") } icon: { Image(systemName: "g.circle.fill") }
            }
            .buttonStyle(.outline)
            .accessibilityIdentifier("signin.google")

            HStack(spacing: Metrics.Space.md) {
                Rectangle().fill(Palette.hair).frame(height: Metrics.hairline)
                Text("auth.or").font(Typography.mono(10)).foregroundStyle(Palette.muted2)
                Rectangle().fill(Palette.hair).frame(height: Metrics.hairline)
            }

            TextField(text: $model.email, prompt: Text("auth.email.placeholder").foregroundColor(Palette.muted2)) {
                Text("account.email")
            }
            .textContentType(.emailAddress)
            .keyboardType(.emailAddress)
            .textInputAutocapitalization(.never)
            .autocorrectionDisabled()
            .submitLabel(.send)
            .onSubmit { Task { await model.sendMagicLink() } }
            .font(Typography.body(15))
            .foregroundStyle(Palette.ink)
            .padding(.horizontal, Metrics.Space.lg)
            .frame(minHeight: 48)
            .background(Palette.deep, in: RoundedRectangle(cornerRadius: Metrics.Radius.sm, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: Metrics.Radius.sm, style: .continuous).stroke(Palette.hairStrong, lineWidth: Metrics.hairline))
            .accessibilityIdentifier("signin.email")

            Button {
                Task { await model.sendMagicLink() }
            } label: {
                Text("auth.email.send")
            }
            .buttonStyle(.prominent)
            .accessibilityIdentifier("signin.sendLink")
        }
    }

    private func linkSent(_ model: SignInViewModel, address: String) -> some View {
        @Bindable var model = model
        return VStack(alignment: .leading, spacing: Metrics.Space.md) {
            HStack(spacing: Metrics.Space.sm) {
                Image(systemName: "envelope.badge.fill").foregroundStyle(Palette.teal)
                Text("auth.email.sent.title")
                    .font(Typography.display(18))
                    .foregroundStyle(Palette.ink)
            }
            Text("auth.email.sent.body \(address)")
                .font(Typography.body(14))
                .foregroundStyle(Palette.muted)
                .fixedSize(horizontal: false, vertical: true)
                .accessibilityIdentifier("signin.linkSent")

            Text("auth.code.prompt")
                .font(Typography.body(14))
                .foregroundStyle(Palette.ink)
                .fixedSize(horizontal: false, vertical: true)

            HStack(spacing: Metrics.Space.sm) {
                TextField(text: $model.code, prompt: Text(verbatim: "12345678").foregroundColor(Palette.muted2)) {
                    Text("auth.code.label")
                }
                .textContentType(.oneTimeCode)
                .keyboardType(.numberPad)
                .submitLabel(.go)
                .onSubmit { Task { await model.verifyCode() } }
                .font(Typography.mono(18, weight: .semibold))
                .foregroundStyle(Palette.ink)
                .padding(.horizontal, Metrics.Space.lg)
                .frame(minHeight: 48)
                .background(Palette.abyss, in: RoundedRectangle(cornerRadius: Metrics.Radius.sm, style: .continuous))
                .overlay(RoundedRectangle(cornerRadius: Metrics.Radius.sm, style: .continuous).stroke(Palette.hairStrong, lineWidth: Metrics.hairline))
                .accessibilityIdentifier("signin.code")

                Button { Task { await model.verifyCode() } } label: { Text("auth.code.verify") }
                    .buttonStyle(.prominent)
                    .frame(width: 120)
                    .accessibilityIdentifier("signin.verifyCode")
            }

            Button { model.useDifferentEmail() } label: { Text("auth.email.different") }
                .buttonStyle(.outline)
        }
        .padding(Metrics.Space.lg)
        .background(Palette.deep, in: RoundedRectangle(cornerRadius: Metrics.Radius.md, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: Metrics.Radius.md, style: .continuous).stroke(Palette.hairActive, lineWidth: Metrics.hairline))
    }

    private func handleApple(_ result: Result<ASAuthorization, any Error>, model: SignInViewModel) {
        switch result {
        case .failure:
            // Cancelled or failed at the system sheet; nothing was sent to Supabase.
            return
        case .success(let authorization):
            guard let credential = authorization.credential as? ASAuthorizationAppleIDCredential,
                  let tokenData = credential.identityToken,
                  let idToken = String(data: tokenData, encoding: .utf8) else { return }
            let name = credential.fullName.flatMap { PersonNameComponentsFormatter.localizedString(from: $0, style: .default) }
            let raw = nonce.raw
            nonce = AppleSignInNonce()   // single use
            Task { await model.signInWithApple(idToken: idToken, nonce: raw, fullName: name?.isEmpty == false ? name : nil) }
        }
    }
}
