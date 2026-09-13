import SwiftUI

/// P-103: today's pulses are used. Plain language, the code small beneath (SPEC §21); subscriptions lead,
/// top-ups second (SPEC §18). Purchases arrive with IAP — the buttons here explain, they don't sell yet.
struct PulseSpentSheet: View {
    @Environment(PulseStore.self) private var pulses
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            VStack(alignment: .leading, spacing: Metrics.Space.xl) {
                VStack(alignment: .leading, spacing: Metrics.Space.sm) {
                    Eyebrow(text: "pulse.spent.eyebrow", tint: Palette.amber)
                    Text("pulse.error.spent")
                        .font(Typography.display(24))
                        .foregroundStyle(Palette.ink)
                        .fixedSize(horizontal: false, vertical: true)
                    TimelineView(.periodic(from: .now, by: 1)) { timeline in
                        if let countdown = pulses.countdown(now: timeline.date) {
                            Text("pulse.spent.countdown \(countdown)")
                                .font(Typography.mono(11))
                                .foregroundStyle(Palette.muted)
                        }
                    }
                    Text(verbatim: PulseCode.spent.rawValue)
                        .font(Typography.mono(9))
                        .foregroundStyle(Palette.muted2)
                        .accessibilityIdentifier("pulse.spent.code")
                }
                VStack(alignment: .leading, spacing: Metrics.Space.md) {
                    Text("pulse.spent.subscribe")
                        .font(Typography.body(15, weight: .medium))
                        .foregroundStyle(Palette.ink)
                    Text("pulse.spent.topup")
                        .font(Typography.body(13))
                        .foregroundStyle(Palette.muted)
                    Text("pulse.spent.comingSoon")
                        .font(Typography.mono(10))
                        .foregroundStyle(Palette.muted2)
                }
                Spacer()
            }
            .padding(Metrics.Space.lg)
            .frame(maxWidth: 560)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
            .background(Palette.abyss.ignoresSafeArea())
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button { dismiss() } label: { Text("common.done") }
                }
            }
        }
        .presentationDetents([.medium])
        .presentationDragIndicator(.visible)
    }
}
