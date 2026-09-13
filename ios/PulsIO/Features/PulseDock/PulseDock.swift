import SwiftUI

/// The dock (FRONTEND §D): the fire button with the liquid core alive at rest, the PULSE label and the
/// availability line. Signed-out taps go to the gate; spent taps open the spent sheet.
struct PulseDock: View {
    @Environment(PulseStore.self) private var pulses
    @Environment(SessionStore.self) private var session
    let controller: PulseFXController
    let onFire: () -> Void
    let onSpent: () -> Void

    static let buttonSize: CGFloat = 72
    static let bezel: CGFloat = 3

    var body: some View {
        VStack(spacing: Metrics.Space.sm) {
            Button {
                if pulses.isSpent { onSpent() } else { onFire() }
            } label: {
                ZStack {
                    Circle().fill(Palette.deep)
                    PulseCoreView(controller: controller, inner: Self.buttonSize / 2 - Self.bezel)
                        .frame(width: Self.buttonSize, height: Self.buttonSize)
                        .clipShape(Circle())
                        .opacity(pulses.isSpent ? 0.35 : 1)
                    Circle().stroke(pulses.isSpent ? Palette.hairStrong : Palette.hairActive, lineWidth: Self.bezel)
                }
                .frame(width: Self.buttonSize, height: Self.buttonSize)
                .shadow(color: Palette.teal.opacity(pulses.isSpent ? 0 : 0.35), radius: 14, y: 6)
                .anchorPreference(key: PulseButtonAnchor.self, value: .bounds) { $0 }
            }
            .buttonStyle(.plain)
            .disabled(controller.isRunning || pulses.isFiring)
            .accessibilityLabel(Text("pulse.fire"))
            .accessibilityIdentifier("pulse.fire")

            Text("pulse.label")
                .font(Typography.mono(10, weight: .semibold))
                .tracking(0.28)
                .textCase(.uppercase)
                .foregroundStyle(Palette.teal)
            TimelineView(.periodic(from: .now, by: 1)) { timeline in
                Text(stateLine(now: timeline.date))
                    .font(Typography.mono(8))
                    .tracking(0.14)
                    .textCase(.uppercase)
                    .foregroundStyle(pulses.isSpent ? Palette.amber : Palette.muted2)
                    .accessibilityIdentifier("pulse.state")
            }
        }
    }

    private func stateLine(now: Date) -> LocalizedStringResource {
        if controller.isRunning || pulses.isFiring { return "pulse.state.firing" }
        guard session.isSignedIn, let status = pulses.status else { return "pulse.state.signIn" }
        if !status.canPulse {
            if let countdown = pulses.countdown(now: now) { return "pulse.state.spentNext \(countdown)" }
            return "pulse.state.spent"
        }
        if let n = status.available { return "pulse.state.available \(n)" }
        return "pulse.state.unlimited"
    }
}

/// The button core: the same metaball goo as the ceremony, churning at ~30 fps at rest.
struct PulseCoreView: View {
    let controller: PulseFXController
    let inner: CGFloat

    var body: some View {
        TimelineView(.periodic(from: .now, by: 1.0 / 30)) { timeline in
            Canvas { context, size in
                let t = timeline.date.timeIntervalSinceReferenceDate.truncatingRemainder(dividingBy: 3600)
                let since = controller.lastEndedAt.map { timeline.date.timeIntervalSince($0) }
                let calm = PulseFXChoreography.calmAt(secondsSinceLastPulse: since)
                controller.renderer.renderIdle(t, center: CGPoint(x: size.width / 2, y: size.height / 2), inner: inner, calm: calm, in: &context)
            }
        }
        .opacity(controller.isRunning ? 0 : 1)   // during a pulse the liquid lives on the overlay
    }
}

/// Where the fire button is, so the overlay can start the liquid inside it.
struct PulseButtonAnchor: PreferenceKey {
    static let defaultValue: Anchor<CGRect>? = nil
    static func reduce(value: inout Anchor<CGRect>?, nextValue: () -> Anchor<CGRect>?) {
        value = nextValue() ?? value
    }
}
