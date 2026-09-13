import SwiftUI

/// PulsScore (FRONTEND §H): the ring, the verdict in words, the six components with how each is obtained,
/// and the share entry point. Viewable signed-out.
struct PulsScoreScreen: View {
    @Environment(ScoreStore.self) private var scores
    @Environment(\.dismiss) private var dismiss
    @State private var showShare = false

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: Metrics.Space.xl) {
                    PulsScoreRing(breakdown: scores.breakdown)
                        .frame(width: 220, height: 220)
                        .padding(.top, Metrics.Space.md)
                        .accessibilityIdentifier("pulsscore.ring")
                    VStack(spacing: Metrics.Space.xs) {
                        Text(scores.breakdown?.verdict.label ?? "pulsscore.loading")
                            .font(Typography.display(22))
                            .foregroundStyle(Palette.ink)
                            .multilineTextAlignment(.center)
                            .accessibilityIdentifier("pulsscore.verdict")
                        if let at = scores.breakdown?.calculatedAt {
                            Text("pulsscore.updated \(at.formatted(.dateTime.hour().minute()))")
                                .font(Typography.mono(10)).foregroundStyle(Palette.muted2)
                        }
                    }
                    if let b = scores.breakdown {
                        VStack(spacing: 0) {
                            ForEach(b.components) { c in
                                HStack(spacing: Metrics.Space.md) {
                                    Circle().fill(PanelTone.color(c.tone)).frame(width: 8, height: 8)
                                    VStack(alignment: .leading, spacing: 2) {
                                        Text(c.label).font(Typography.body(14, weight: .medium)).foregroundStyle(Palette.ink)
                                        Text(c.basisLabel).font(Typography.mono(9)).tracking(0.1).textCase(.uppercase)
                                            .foregroundStyle(c.basis == .measured ? Palette.muted : Palette.amber)
                                    }
                                    Spacer()
                                    Text("\(c.weight)%").font(Typography.mono(10)).foregroundStyle(Palette.muted2)
                                    Text(String(c.score)).font(Typography.display(18)).foregroundStyle(PanelTone.color(c.tone)).monospacedDigit()
                                        .frame(width: 44, alignment: .trailing)
                                }
                                .padding(.vertical, Metrics.Space.md)
                                .frame(minHeight: 44)
                                Rectangle().fill(Palette.hair).frame(height: Metrics.hairline)
                            }
                        }
                        Text("pulsscore.honesty \(b.measuredCount) \(b.componentCount)")
                            .font(Typography.mono(10))
                            .foregroundStyle(Palette.muted)
                            .multilineTextAlignment(.center)
                            .fixedSize(horizontal: false, vertical: true)
                            .accessibilityIdentifier("pulsscore.honesty")
                    }
                    Button { showShare = true } label: {
                        Label { Text("share.cta") } icon: { Image(systemName: "square.and.arrow.up") }
                    }
                    .buttonStyle(.prominent)
                    .disabled(scores.breakdown == nil)
                    .accessibilityIdentifier("pulsscore.share")
                }
                .padding(Metrics.Space.lg)
                .frame(maxWidth: 560)
                .frame(maxWidth: .infinity)
            }
            .background(Palette.abyss.ignoresSafeArea())
            .navigationTitle(Text("pulsscore.title"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) { Button { dismiss() } label: { Text("common.done") } }
            }
        }
        .task { if scores.breakdown == nil { await scores.refresh() } }
        .sheet(isPresented: $showShare) { ShareCardsSheet(preselected: [.pulsScore]) }
    }
}
