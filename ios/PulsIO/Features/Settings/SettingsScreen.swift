import SwiftUI
import UIKit

/// Settings (FRONTEND §I). Reachable signed-out — district and preferences live on the device — only the
/// account section needs sign-in. Wraps the existing Account screen.
struct SettingsScreen: View {
    @Environment(SessionStore.self) private var session
    @Environment(AccessGate.self) private var gate
    @Environment(DistrictStore.self) private var districts
    @Environment(PreferencesStore.self) private var preferences
    @Environment(PulseStore.self) private var pulses
    @Environment(PulseFXController.self) private var pulseFX
    @Environment(\.dismiss) private var dismiss
    let tiers: any TierRepository

    @State private var showDistrictPicker = false
    @State private var showPrimer = false
    @State private var showUpgrade = false
    @State private var showAccount = false

    var body: some View {
        @Bindable var pulseFX = pulseFX
        @Bindable var gate = gate
        NavigationStack {
            List {
                accountSection
                districtSection
                preferencesSection
                planSection
                locationSection
                Section {
                    Toggle(isOn: $pulseFX.ceremonyEnabled) {
                        VStack(alignment: .leading, spacing: 2) {
                            Text("settings.motion.ceremony").foregroundStyle(Palette.ink)
                            Text("settings.motion.ceremony.note").font(Typography.mono(10)).foregroundStyle(Palette.muted2)
                        }
                    }
                    .tint(Palette.teal)
                    .accessibilityIdentifier("settings.ceremony")
                } header: { Eyebrow(text: "settings.motion") }
                .listRowBackground(Palette.deep)
                languageSection
                aboutSection
            }
            .scrollContentBackground(.hidden)
            .background(Palette.abyss.ignoresSafeArea())
            .navigationTitle(Text("settings.title"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar { ToolbarItem(placement: .confirmationAction) { Button { dismiss() } label: { Text("common.done") }.accessibilityIdentifier("settings.done") } }
        }
        .sheet(isPresented: $showDistrictPicker) { DistrictPickerSheet(framing: .general) }
        .sheet(isPresented: $showPrimer) { LocationPrimerSheet() }
        .sheet(isPresented: $showUpgrade) { UpgradeSheet(tiers: tiers) }
        .sheet(isPresented: $showAccount) { AccountView() }
        // The gate presents over Settings (RootView steps aside while Settings is showing).
        .sheet(isPresented: $gate.isPresentingSignIn, onDismiss: { gate.cancel() }) { SignInSheet() }
        .task { await pulses.refresh() }
    }

    // MARK: Sections

    private var accountSection: some View {
        Section {
            if session.isSignedIn {
                Button { showAccount = true } label: {
                    LabeledContent {
                        HStack(spacing: Metrics.Space.sm) {
                            Text(session.profile?.displayName ?? session.user?.email ?? "").foregroundStyle(Palette.muted).lineLimit(1)
                            Image(systemName: "chevron.right").font(.system(size: 12, weight: .semibold)).foregroundStyle(Palette.muted2)
                        }
                    } label: { Text("account.title").foregroundStyle(Palette.ink) }
                }
                .accessibilityIdentifier("settings.account")
            } else {
                Button { gate.presentSignIn() } label: {
                    LabeledContent {
                        Text("settings.signIn.hint").font(Typography.mono(10)).foregroundStyle(Palette.muted2).multilineTextAlignment(.trailing)
                    } label: { Text("settings.signIn").foregroundStyle(Palette.teal) }
                }
                .accessibilityIdentifier("settings.signIn")
            }
        } header: { Eyebrow(text: "account.eyebrow") }
        .listRowBackground(Palette.deep)
    }

    private var districtSection: some View {
        Section {
            Button { showDistrictPicker = true } label: {
                LabeledContent {
                    HStack(spacing: Metrics.Space.sm) {
                        if let d = districts.district { Text(d.label).foregroundStyle(Palette.ink) } else { Text("district.chip.unset").foregroundStyle(Palette.muted) }
                        Image(systemName: "chevron.right").font(.system(size: 12, weight: .semibold)).foregroundStyle(Palette.muted2)
                    }
                } label: { Text("district.title").foregroundStyle(Palette.ink) }
            }
            .accessibilityIdentifier("settings.district")
            if districts.locationAvailability == .authorized {
                Button { Task { _ = await districts.locate() } } label: {
                    Label { Text("settings.district.useLocation") } icon: { Image(systemName: "location.fill") }.foregroundStyle(Palette.teal)
                }
                .accessibilityIdentifier("settings.district.locate")
            }
        } header: { Eyebrow(text: "district.title") } footer: {
            Text(districts.source == .gps ? "district.source.gps.note" : "settings.district.note").font(Typography.mono(10)).foregroundStyle(Palette.muted2)
        }
        .listRowBackground(Palette.deep)
    }

    private var preferencesSection: some View {
        Section {
            VStack(alignment: .leading, spacing: Metrics.Space.sm) {
                Text("onboarding.prefs.iAm").font(Typography.mono(10)).tracking(0.14).textCase(.uppercase).foregroundStyle(Palette.muted)
                FlowChips {
                    SelectableChip(title: "onboarding.type.mauritian", symbol: "house.fill", isOn: preferences.userType == .mauritian) { set(.mauritian) }
                    SelectableChip(title: "onboarding.type.tourist", symbol: "airplane", isOn: preferences.userType == .tourist) { set(.tourist) }
                    SelectableChip(title: "onboarding.type.pro", symbol: "briefcase.fill", isOn: preferences.userType == .pro) { set(.pro) }
                }
                Text("onboarding.prefs.priorities").font(Typography.mono(10)).tracking(0.14).textCase(.uppercase).foregroundStyle(Palette.muted).padding(.top, Metrics.Space.xs)
                FlowChips {
                    chip(.ceb, "bolt.fill", "onboarding.priority.ceb"); chip(.weather, "cloud.sun.fill", "onboarding.priority.weather")
                    chip(.traffic, "car.fill", "onboarding.priority.traffic"); chip(.news, "newspaper.fill", "onboarding.priority.news")
                    chip(.cyclone, "hurricane", "onboarding.priority.cyclone"); chip(.fuel, "fuelpump.fill", "onboarding.priority.fuel")
                }
                Text("onboarding.prefs.count \(preferences.priorities.count) \(Priority.maxSelected)").font(Typography.mono(10)).foregroundStyle(Palette.muted2)
                    .accessibilityIdentifier("settings.prefs.count")
            }
            .padding(.vertical, Metrics.Space.xs)
        } header: { Eyebrow(text: "settings.preferences") } footer: {
            Text("settings.preferences.note").font(Typography.mono(10)).foregroundStyle(Palette.muted2)
        }
        .listRowBackground(Palette.deep)
    }

    private func chip(_ p: Priority, _ symbol: String, _ title: LocalizedStringResource) -> some View {
        SelectableChip(title: title, symbol: symbol, isOn: preferences.priorities.contains(p)) {
            preferences.toggle(p)
            Task { await preferences.syncIfSignedIn() }
        }
        .accessibilityIdentifier("settings.priority.\(p.rawValue)")
    }

    private func set(_ type: UserType) {
        preferences.setUserType(type)
        Task { await preferences.syncIfSignedIn() }
    }

    private var planSection: some View {
        Section {
            LabeledContent { Text(pulses.status?.tierName ?? String(localized: "tier.free")).foregroundStyle(Palette.teal) } label: { Text("account.tier").foregroundStyle(Palette.ink) }
            if let status = pulses.status {
                LabeledContent {
                    Text(status.isUnlimited ? String(localized: "pulse.state.unlimited") : "\(status.quotaRemaining ?? 0) / \(status.pulsesPerDay ?? 0)").foregroundStyle(Palette.ink).monospacedDigit()
                } label: { Text("settings.plan.pulsesToday").foregroundStyle(Palette.ink) }
                LabeledContent { Text(String(status.topupBalance)).foregroundStyle(Palette.ink).monospacedDigit() } label: { Text("settings.plan.topups").foregroundStyle(Palette.ink) }
            } else if !session.isSignedIn {
                Text("settings.plan.signedOut").font(Typography.mono(10)).foregroundStyle(Palette.muted2)
            }
            Button { showUpgrade = true } label: {
                Label { Text("settings.plan.upgrade") } icon: { Image(systemName: "arrow.up.circle.fill") }.foregroundStyle(Palette.teal)
            }
            .accessibilityIdentifier("settings.upgrade")
        } header: { Eyebrow(text: "account.plan.eyebrow") }
        .listRowBackground(Palette.deep)
    }

    private var locationSection: some View {
        Section {
            LabeledContent {
                Text(locationLabel).foregroundStyle(districts.locationAvailability == .authorized ? Palette.green : Palette.muted)
            } label: { Text("settings.location").foregroundStyle(Palette.ink) }
            .accessibilityIdentifier("settings.location.status")
            switch districts.locationAvailability {
            case .denied, .restricted:
                Link(destination: URL(string: UIApplication.openSettingsURLString)!) {
                    Label { Text("district.enableInSettings") } icon: { Image(systemName: "gear") }.foregroundStyle(Palette.teal)
                }
            case .notDetermined:
                Button { showPrimer = true } label: {
                    Label { Text("location.allow") } icon: { Image(systemName: "location") }.foregroundStyle(Palette.teal)
                }
            case .authorized:
                EmptyView()
            }
        } header: { Eyebrow(text: "location.eyebrow") } footer: {
            Text("location.privacy").font(Typography.mono(10)).foregroundStyle(Palette.muted2)
        }
        .listRowBackground(Palette.deep)
    }

    private var locationLabel: LocalizedStringResource {
        switch districts.locationAvailability {
        case .authorized: "settings.location.on"
        case .denied, .restricted: "settings.location.off"
        case .notDetermined: "settings.location.notAsked"
        }
    }

    private var languageSection: some View {
        Section {
            LabeledContent { Text(verbatim: "English").foregroundStyle(Palette.ink) } label: { Text("settings.language").foregroundStyle(Palette.ink) }
            LabeledContent { Text("settings.language.soon").font(Typography.mono(10)).foregroundStyle(Palette.muted2) } label: { Text(verbatim: "Français").foregroundStyle(Palette.muted) }
        } header: { Eyebrow(text: "settings.language") } footer: {
            Text("settings.language.note").font(Typography.mono(10)).foregroundStyle(Palette.muted2)
        }
        .listRowBackground(Palette.deep)
    }

    private var aboutSection: some View {
        Section {
            LabeledContent { Text(verbatim: Self.version).foregroundStyle(Palette.muted).monospacedDigit() } label: { Text("settings.about.version").foregroundStyle(Palette.ink) }
                .accessibilityIdentifier("settings.version")
            Link(destination: URL(string: "https://pulsio.mu/privacy/")!) { Label { Text("settings.about.privacy") } icon: { Image(systemName: "hand.raised.fill") }.foregroundStyle(Palette.teal) }
            Link(destination: URL(string: "https://pulsio.mu/terms/")!) { Label { Text("settings.about.terms") } icon: { Image(systemName: "doc.text.fill") }.foregroundStyle(Palette.teal) }
            Link(destination: URL(string: "https://pulsio.mu/refunds/")!) { Label { Text("settings.about.refunds") } icon: { Image(systemName: "arrow.uturn.backward.circle.fill") }.foregroundStyle(Palette.teal) }
            Link(destination: URL(string: "https://www.openstreetmap.org/copyright")!) {
                VStack(alignment: .leading, spacing: 2) {
                    Text("map.attribution").foregroundStyle(Palette.ink)
                    Text("settings.about.odbl").font(Typography.mono(10)).foregroundStyle(Palette.muted2)
                }
            }
            .accessibilityIdentifier("settings.attribution")
        } header: { Eyebrow(text: "settings.about") }
        .listRowBackground(Palette.deep)
    }

    private static var version: String {
        let v = Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "?"
        let b = Bundle.main.object(forInfoDictionaryKey: "CFBundleVersion") as? String ?? "?"
        return "\(v) (\(b))"
    }
}

/// The plan chooser, fed by pulsio_tier_rules (subscriptions lead, SPEC §18). Purchases arrive with IAP.
struct UpgradeSheet: View {
    let tiers: any TierRepository
    @Environment(PulseStore.self) private var pulses
    @Environment(\.dismiss) private var dismiss
    @State private var rules: [TierRule] = []

    private static let prices: [Tier: LocalizedStringResource] = [.free: "tier.price.free", .t1: "tier.price.t1", .t2: "tier.price.t2", .pro: "tier.price.pro"]

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: Metrics.Space.md) {
                    Eyebrow(text: "settings.plan.upgrade", tint: Palette.teal)
                    Text("upgrade.title").font(Typography.display(24)).foregroundStyle(Palette.ink)
                    ForEach(rules) { rule in
                        let current = pulses.status?.tier == rule.tier
                        VStack(alignment: .leading, spacing: Metrics.Space.xs) {
                            HStack {
                                Text(rule.displayName).font(Typography.display(16)).foregroundStyle(Palette.ink)
                                Spacer()
                                Text(Self.prices[rule.tier] ?? "tier.price.pro").font(Typography.mono(11, weight: .semibold)).foregroundStyle(Palette.teal)
                            }
                            Text("upgrade.line \(rule.pulsesPerDay.map(String.init) ?? String(localized: "pulse.state.unlimited")) \(rule.deviceMax) \(rule.ads ? String(localized: "upgrade.ads.yes") : String(localized: "upgrade.ads.no"))")
                                .font(Typography.mono(10)).foregroundStyle(Palette.muted).fixedSize(horizontal: false, vertical: true)
                            if current { Text("upgrade.current").font(Typography.mono(9)).tracking(0.14).textCase(.uppercase).foregroundStyle(Palette.green) }
                        }
                        .padding(Metrics.Space.md)
                        .background(Palette.deep, in: RoundedRectangle(cornerRadius: Metrics.Radius.sm, style: .continuous))
                        .overlay(RoundedRectangle(cornerRadius: Metrics.Radius.sm, style: .continuous).stroke(current ? Palette.hairActive : Palette.hairStrong, lineWidth: Metrics.hairline))
                        .accessibilityIdentifier("upgrade.tier.\(rule.tier.rawValue)")
                    }
                    Text("pulse.spent.comingSoon").font(Typography.mono(10)).foregroundStyle(Palette.muted2)
                }
                .padding(Metrics.Space.lg)
                .frame(maxWidth: 560)
                .frame(maxWidth: .infinity)
            }
            .background(Palette.abyss.ignoresSafeArea())
            .navigationBarTitleDisplayMode(.inline)
            .toolbar { ToolbarItem(placement: .confirmationAction) { Button { dismiss() } label: { Text("common.done") } } }
        }
        .task { rules = (try? await tiers.rules()) ?? [] }
        .presentationDetents([.large])
    }
}
