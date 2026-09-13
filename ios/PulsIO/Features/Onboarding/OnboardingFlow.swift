import SwiftUI

/// First run (FRONTEND §A): intro → what is a pulse → what matters to you → why location helps → the map.
/// Works signed-out; preferences persist on the device and reconcile to the profile on sign-in. Skippable
/// from step two onward — skipped users get the default panel order.
struct OnboardingFlow: View {
    @Environment(PreferencesStore.self) private var preferences
    @Environment(PulseFXController.self) private var pulseFX
    @Environment(\.horizontalSizeClass) private var sizeClass
    @State private var step = 0
    private let steps = 5

    var body: some View {
        ZStack {
            Atmosphere()
            content
                .frame(maxWidth: 560)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .overlay(alignment: .topTrailing) {
            if step > 0 {
                Button { Task { await preferences.completeOnboarding() } } label: {
                    Text("onboarding.skip")
                        .font(Typography.mono(11, weight: .medium))
                        .tracking(Typography.eyebrowTracking)
                        .textCase(.uppercase)
                        .foregroundStyle(Palette.muted)
                        .padding(Metrics.Space.lg)
                        .frame(minHeight: 44)
                }
                .buttonStyle(.plain)
                .accessibilityIdentifier("onboarding.skip")
            }
        }
    }

    @ViewBuilder
    private var content: some View {
        VStack(spacing: 0) {
            Group {
                switch step {
                case 0: IntroStep(onNext: advance)
                case 1: PulseStep(controller: pulseFX, onNext: advance)
                case 2: PreferencesStep(onNext: advance)
                case 3: LocationStep(onNext: advance)
                default: MapTutorialStep(onNext: { Task { await preferences.completeOnboarding() } })
                }
            }
            .id(step)
            .transition(.asymmetric(insertion: .move(edge: .trailing).combined(with: .opacity), removal: .move(edge: .leading).combined(with: .opacity)))
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .padding(.horizontal, Metrics.Space.xl)

            StepDots(count: steps, current: step)
                .padding(.bottom, Metrics.Space.xl)
        }
        .animation(Metrics.Motion.entrance, value: step)
    }

    private func advance() {
        withAnimation(Metrics.Motion.entrance) { step = min(step + 1, steps - 1) }
    }
}

private struct StepDots: View {
    let count: Int
    let current: Int

    var body: some View {
        HStack(spacing: 6) {
            ForEach(0..<count, id: \.self) { i in
                Capsule()
                    .fill(i == current ? Palette.teal : Palette.teal.opacity(0.2))
                    .frame(width: i == current ? 18 : 8, height: 8)
                    .animation(.easeOut(duration: Metrics.Motion.base), value: current)
            }
        }
        .accessibilityHidden(true)
    }
}

/// The primary action — the web's teal `Get started` button, restyled to the token ramp.
struct OnboardingButton: View {
    let title: LocalizedStringResource
    let identifier: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(title)
                .font(Typography.display(15, weight: .bold))
                .foregroundStyle(Palette.abyss)
                .padding(.horizontal, 40)
                .frame(minHeight: 50)
                .background(Palette.teal, in: RoundedRectangle(cornerRadius: Metrics.Radius.sm, style: .continuous))
                .shadow(color: Palette.teal.opacity(0.35), radius: 16, y: 8)
        }
        .buttonStyle(.plain)
        .accessibilityIdentifier(identifier)
    }
}

// MARK: - Steps

private struct IntroStep: View {
    let onNext: () -> Void

    var body: some View {
        VStack(spacing: Metrics.Space.lg) {
            Spacer()
            BrandMark(size: 128)
                .padding(.bottom, Metrics.Space.sm)
            Wordmark(size: 40)
            Text("onboarding.tagline")
                .font(Typography.mono(12))
                .tracking(0.2)
                .textCase(.uppercase)
                .foregroundStyle(Palette.muted)
            Spacer()
            OnboardingButton(title: "onboarding.getStarted", identifier: "onboarding.next", action: onNext)
            Spacer().frame(height: Metrics.Space.lg)
        }
        .multilineTextAlignment(.center)
    }
}

private struct PulseStep: View {
    let controller: PulseFXController
    let onNext: () -> Void

    var body: some View {
        VStack(spacing: Metrics.Space.lg) {
            Spacer()
            // The real thing, at rest: the liquid core users will tap.
            ZStack {
                Circle().fill(Palette.deep)
                PulseCoreView(controller: controller, inner: 44 - PulseDock.bezel)
                    .frame(width: 88, height: 88)
                    .clipShape(Circle())
                Circle().stroke(Palette.hairActive, lineWidth: PulseDock.bezel)
            }
            .frame(width: 88, height: 88)
            .shadow(color: Palette.teal.opacity(0.35), radius: 18, y: 8)
            .padding(.bottom, Metrics.Space.sm)
            Text("onboarding.pulse.title")
                .font(Typography.display(26))
                .foregroundStyle(Palette.ink)
            Text("onboarding.pulse.body")
                .font(Typography.body(15))
                .lineSpacing(4)
                .foregroundStyle(Palette.muted)
                .frame(maxWidth: 380)
            Text("onboarding.pulse.scarcity")
                .font(Typography.mono(12, weight: .medium))
                .foregroundStyle(Palette.teal)
            Spacer()
            OnboardingButton(title: "onboarding.next", identifier: "onboarding.next", action: onNext)
            Spacer().frame(height: Metrics.Space.lg)
        }
        .multilineTextAlignment(.center)
    }
}

private struct PreferencesStep: View {
    @Environment(PreferencesStore.self) private var preferences
    let onNext: () -> Void

    private static let types: [(UserType, String, LocalizedStringResource)] = [
        (.mauritian, "house.fill", "onboarding.type.mauritian"), (.tourist, "airplane", "onboarding.type.tourist"), (.pro, "briefcase.fill", "onboarding.type.pro"),
    ]
    private static let priorities: [(Priority, String, LocalizedStringResource)] = [
        (.ceb, "bolt.fill", "onboarding.priority.ceb"), (.weather, "cloud.sun.fill", "onboarding.priority.weather"),
        (.traffic, "car.fill", "onboarding.priority.traffic"), (.news, "newspaper.fill", "onboarding.priority.news"),
        (.cyclone, "hurricane", "onboarding.priority.cyclone"), (.fuel, "fuelpump.fill", "onboarding.priority.fuel"),
    ]

    var body: some View {
        VStack(spacing: Metrics.Space.lg) {
            Spacer()
            Text("onboarding.prefs.title").font(Typography.display(26)).foregroundStyle(Palette.ink)
            Text("onboarding.prefs.body").font(Typography.mono(12)).foregroundStyle(Palette.muted)
            VStack(spacing: Metrics.Space.sm) {
                Eyebrow(text: "onboarding.prefs.iAm")
                FlowChips {
                    ForEach(Self.types, id: \.0) { type, symbol, title in
                        SelectableChip(title: title, symbol: symbol, isOn: preferences.userType == type) { preferences.setUserType(type) }
                            .accessibilityIdentifier("onboarding.type.\(type.rawValue)")
                    }
                }
            }
            .padding(.top, Metrics.Space.sm)
            VStack(spacing: Metrics.Space.sm) {
                Eyebrow(text: "onboarding.prefs.priorities")
                FlowChips {
                    ForEach(Self.priorities, id: \.0) { priority, symbol, title in
                        SelectableChip(title: title, symbol: symbol, isOn: preferences.priorities.contains(priority)) { preferences.toggle(priority) }
                            .accessibilityIdentifier("onboarding.priority.\(priority.rawValue)")
                    }
                }
                Text("onboarding.prefs.count \(preferences.priorities.count) \(Priority.maxSelected)")
                    .font(Typography.mono(10)).foregroundStyle(Palette.muted2)
                    .accessibilityIdentifier("onboarding.prefs.count")
            }
            Spacer()
            OnboardingButton(title: "onboarding.continue", identifier: "onboarding.next", action: onNext)
            Spacer().frame(height: Metrics.Space.lg)
        }
        .multilineTextAlignment(.center)
    }
}

/// Why location helps — explained here, before any system prompt (SPEC §10 step 1). The prompt itself is
/// asked in context at first use (the locate button), never during onboarding.
private struct LocationStep: View {
    let onNext: () -> Void

    var body: some View {
        VStack(spacing: Metrics.Space.lg) {
            Spacer()
            Image(systemName: "location.circle")
                .font(.system(size: 56, weight: .thin))
                .foregroundStyle(Palette.teal)
                .padding(.bottom, Metrics.Space.sm)
            Text("location.title").font(Typography.display(26)).foregroundStyle(Palette.ink)
            Text("location.body")
                .font(Typography.body(15)).lineSpacing(4).foregroundStyle(Palette.muted).frame(maxWidth: 400)
            HStack(alignment: .firstTextBaseline, spacing: Metrics.Space.sm) {
                Image(systemName: "lock.fill").foregroundStyle(Palette.teal).font(.system(size: 11, weight: .semibold))
                Text("location.privacy").font(Typography.body(13)).foregroundStyle(Palette.muted)
            }
            .frame(maxWidth: 400)
            Text("onboarding.location.later")
                .font(Typography.mono(11)).foregroundStyle(Palette.muted2).frame(maxWidth: 400)
            Spacer()
            OnboardingButton(title: "onboarding.gotIt", identifier: "onboarding.next", action: onNext)
            Spacer().frame(height: Metrics.Space.lg)
        }
        .multilineTextAlignment(.center)
    }
}

/// What the map does, in four beats — pins are meaning, layers, the dock, your district.
private struct MapTutorialStep: View {
    let onNext: () -> Void

    var body: some View {
        VStack(spacing: Metrics.Space.lg) {
            Spacer()
            Text("onboarding.map.title").font(Typography.display(26)).foregroundStyle(Palette.ink)
            VStack(alignment: .leading, spacing: Metrics.Space.md) {
                TutorialRow(symbol: "mappin.circle.fill", tint: Palette.coral, title: "onboarding.map.pins", text: "onboarding.map.pins.body")
                TutorialRow(symbol: "square.3.layers.3d", tint: Palette.green, title: "onboarding.map.layers", text: "onboarding.map.layers.body")
                TutorialRow(symbol: "waveform.path.ecg", tint: Palette.teal, title: "onboarding.map.pulse", text: "onboarding.map.pulse.body")
                TutorialRow(symbol: "location.fill", tint: Palette.sky, title: "onboarding.map.district", text: "onboarding.map.district.body")
            }
            .padding(Metrics.Space.lg)
            .background(Palette.deep.opacity(0.7), in: RoundedRectangle(cornerRadius: Metrics.Radius.md, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: Metrics.Radius.md, style: .continuous).stroke(Palette.hairStrong, lineWidth: Metrics.hairline))
            Spacer()
            OnboardingButton(title: "onboarding.enter", identifier: "onboarding.next", action: onNext)
            Spacer().frame(height: Metrics.Space.lg)
        }
        .multilineTextAlignment(.center)
    }
}

private struct TutorialRow: View {
    let symbol: String
    let tint: Color
    let title: LocalizedStringResource
    let text: LocalizedStringResource

    var body: some View {
        HStack(alignment: .top, spacing: Metrics.Space.md) {
            Image(systemName: symbol).font(.system(size: 16, weight: .semibold)).foregroundStyle(tint).frame(width: 24)
            VStack(alignment: .leading, spacing: 2) {
                Text(title).font(Typography.body(14, weight: .medium)).foregroundStyle(Palette.ink)
                Text(text).font(Typography.body(12)).foregroundStyle(Palette.muted).fixedSize(horizontal: false, vertical: true)
            }
        }
        .multilineTextAlignment(.leading)
    }
}

/// Wraps chips onto as many centred lines as needed.
struct FlowChips<Content: View>: View {
    @ViewBuilder let content: () -> Content

    var body: some View {
        WrappingStack(spacing: Metrics.Space.sm) { content() }
    }
}

/// Minimal wrapping layout (Layout protocol): rows of chips, each row centred.
private struct WrappingStack: Layout {
    var spacing: CGFloat = 8

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let rows = layoutRows(width: proposal.width ?? .infinity, subviews: subviews)
        let height = rows.reduce(0) { $0 + $1.height } + CGFloat(max(0, rows.count - 1)) * spacing
        return CGSize(width: proposal.width ?? rows.map(\.width).max() ?? 0, height: height)
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        var y = bounds.minY
        for row in layoutRows(width: bounds.width, subviews: subviews) {
            var x = bounds.minX + (bounds.width - row.width) / 2
            for index in row.indices {
                let size = subviews[index].sizeThatFits(.unspecified)
                subviews[index].place(at: CGPoint(x: x, y: y), proposal: .unspecified)
                x += size.width + spacing
            }
            y += row.height + spacing
        }
    }

    private struct Row { var indices: [Int] = []; var width: CGFloat = 0; var height: CGFloat = 0 }

    private func layoutRows(width: CGFloat, subviews: Subviews) -> [Row] {
        var rows: [Row] = [Row()]
        for (i, sub) in subviews.enumerated() {
            let size = sub.sizeThatFits(.unspecified)
            let extra = rows[rows.count - 1].indices.isEmpty ? size.width : size.width + spacing
            if rows[rows.count - 1].width + extra > width, !rows[rows.count - 1].indices.isEmpty { rows.append(Row()) }
            rows[rows.count - 1].indices.append(i)
            rows[rows.count - 1].width += rows[rows.count - 1].indices.count == 1 ? size.width : size.width + spacing
            rows[rows.count - 1].height = max(rows[rows.count - 1].height, size.height)
        }
        return rows
    }
}
