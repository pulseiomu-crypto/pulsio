import SwiftUI

/// Minimal account management — there are no passwords, so: display name, email, sign out,
/// sign out everywhere (SPEC §17), delete account (App Store 5.1.1(v), genuinely deletes).
struct AccountView: View {
    @Environment(SessionStore.self) private var session
    @Environment(DistrictStore.self) private var districts
    @Environment(\.dismiss) private var dismiss
    @State private var displayName = ""
    @State private var showDistrictPicker = false
    @State private var isConfirmingDelete = false
    @State private var isWorking = false
    @State private var errorKey: String?

    var body: some View {
        NavigationStack {
            List {
                Section {
                    LabeledContent {
                        TextField(text: $displayName, prompt: Text("account.displayName.placeholder").foregroundColor(Palette.muted2)) {
                            Text("account.displayName")
                        }
                        .multilineTextAlignment(.trailing)
                        .foregroundStyle(Palette.ink)
                        .submitLabel(.done)
                        .onSubmit { Task { await saveDisplayName() } }
                        .accessibilityIdentifier("account.displayName")
                    } label: {
                        Text("account.displayName")
                    }

                    LabeledContent {
                        Text(session.user?.email ?? "—").foregroundStyle(Palette.muted)
                    } label: {
                        Text("account.email")
                    }
                    .accessibilityIdentifier("account.email")

                    if let provider = session.user?.provider {
                        Text("account.signedInWith \(providerName(provider))")
                            .font(Typography.mono(10))
                            .foregroundStyle(Palette.muted2)
                    }
                } header: {
                    Eyebrow(text: "account.eyebrow")
                }
                .listRowBackground(Palette.deep)

                Section {
                    LabeledContent {
                        Text(tierName(session.profile?.tier ?? .free)).foregroundStyle(Palette.teal)
                    } label: {
                        Text("account.tier")
                    }
                } header: {
                    Eyebrow(text: "account.plan.eyebrow")
                }
                .listRowBackground(Palette.deep)

                Section {
                    Button { showDistrictPicker = true } label: {
                        LabeledContent {
                            HStack(spacing: Metrics.Space.sm) {
                                if let district = districts.district {
                                    Text(district.label).foregroundStyle(Palette.ink)
                                } else {
                                    Text("district.chip.unset").foregroundStyle(Palette.muted)
                                }
                                Image(systemName: "chevron.right").font(.system(size: 12, weight: .semibold)).foregroundStyle(Palette.muted2)
                            }
                        } label: {
                            Text("district.title")
                        }
                    }
                    .accessibilityIdentifier("account.district")
                } header: {
                    Eyebrow(text: "district.title")
                } footer: {
                    Text(districts.source == .gps ? "district.source.gps.note" : "district.source.manual.note")
                        .font(Typography.mono(10))
                        .foregroundStyle(Palette.muted2)
                }
                .listRowBackground(Palette.deep)

                Section {
                    Button { Task { await run { try await session.signOut(everywhere: false) }; dismiss() } } label: {
                        Text("account.signOut")
                    }
                    .accessibilityIdentifier("account.signOut")

                    Button { Task { await run { try await session.signOut(everywhere: true) }; dismiss() } } label: {
                        VStack(alignment: .leading, spacing: 2) {
                            Text("account.signOutAll")
                            Text("account.signOutAll.note")
                                .font(Typography.mono(10))
                                .foregroundStyle(Palette.muted2)
                        }
                    }
                    .accessibilityIdentifier("account.signOutAll")
                }
                .listRowBackground(Palette.deep)
                .foregroundStyle(Palette.ink)

                Section {
                    Button(role: .destructive) { isConfirmingDelete = true } label: {
                        Text("account.delete").foregroundStyle(Palette.coral)
                    }
                    .accessibilityIdentifier("account.delete")
                } footer: {
                    Text("account.delete.footer")
                        .font(Typography.mono(10))
                        .foregroundStyle(Palette.muted2)
                }
                .listRowBackground(Palette.deep)

                if let errorKey {
                    Section {
                        Text(LocalizedStringResource(stringLiteral: errorKey))
                            .font(Typography.mono(11))
                            .foregroundStyle(Palette.coral)
                    }
                    .listRowBackground(Color.clear)
                }
            }
            .scrollContentBackground(.hidden)
            .background(Palette.abyss.ignoresSafeArea())
            .navigationTitle(Text("account.title"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button { dismiss() } label: { Text("common.done") }
                        .accessibilityIdentifier("account.done")
                }
            }
            .disabled(isWorking)
            .confirmationDialog(Text("account.delete.confirm.title"), isPresented: $isConfirmingDelete, titleVisibility: .visible) {
                Button(role: .destructive) {
                    Task { await run { try await session.deleteAccount() }; if errorKey == nil { dismiss() } }
                } label: {
                    Text("account.delete.confirm.action")
                }
                .accessibilityIdentifier("account.delete.confirm")
                Button(role: .cancel) {} label: { Text("common.cancel") }
            } message: {
                Text("account.delete.confirm.body")
            }
        }
        .sheet(isPresented: $showDistrictPicker) { DistrictPickerSheet(framing: .general) }
        .onAppear { displayName = session.profile?.displayName ?? "" }
        .onChange(of: session.profile?.displayName) { _, new in displayName = new ?? "" }
    }

    private func saveDisplayName() async {
        await run { try await session.updateDisplayName(displayName) }
    }

    private func run(_ work: () async throws -> Void) async {
        isWorking = true
        errorKey = nil
        defer { isWorking = false }
        do { try await work() } catch { errorKey = "account.error.generic" }
    }

    private func providerName(_ provider: String) -> String {
        switch provider {
        case "apple": "Apple"
        case "google": "Google"
        case "email": "Email"
        default: provider
        }
    }

    private func tierName(_ tier: Tier) -> LocalizedStringResource {
        switch tier {
        case .free: "tier.free"
        case .t1: "tier.t1"
        case .t2: "tier.t2"
        case .pro: "tier.pro"
        }
    }
}
