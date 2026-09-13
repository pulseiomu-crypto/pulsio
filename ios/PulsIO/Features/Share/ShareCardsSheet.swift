import SwiftUI

/// Pick which cards and which shape, preview them, share as images. Cards stay separate; more than one can
/// go at once (SPEC §16).
struct ShareCardsSheet: View {
    @Environment(ScoreStore.self) private var scores
    @Environment(PulseResultStore.self) private var result
    @Environment(DistrictStore.self) private var districts
    @Environment(\.dismiss) private var dismiss
    var preselected: Set<CardType> = [.pulsScore]
    /// Present when a report is being shared; nil otherwise (reports aren't built yet).
    var report: ReportCardModel? = nil

    @State private var selected: Set<CardType> = []
    @State private var format: CardFormat = .stories
    @State private var rendered: [CardImage] = []
    @State private var isRendering = false

    private var available: [CardType] {
        var types: [CardType] = []
        if result.hasResult { types.append(.pulseResult) }
        if scores.breakdown != nil { types.append(.pulsScore) }
        if report != nil { types.append(.report) }
        return types
    }

    var body: some View {
        NavigationStack {
            VStack(alignment: .leading, spacing: Metrics.Space.lg) {
                Picker("share.format", selection: $format) {
                    ForEach(CardFormat.allCases) { f in Text(f.label).tag(f) }
                }
                .pickerStyle(.segmented)
                .accessibilityIdentifier("share.format")

                VStack(alignment: .leading, spacing: Metrics.Space.sm) {
                    Eyebrow(text: "share.cards.eyebrow")
                    ForEach(available) { type in
                        Toggle(isOn: Binding(get: { selected.contains(type) }, set: { on in if on { selected.insert(type) } else { selected.remove(type) } })) {
                            Text(type.label).font(Typography.body(14)).foregroundStyle(Palette.ink)
                        }
                        .tint(Palette.teal)
                        .frame(minHeight: 44)
                        .accessibilityIdentifier("share.card.\(type.rawValue)")
                    }
                }

                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: Metrics.Space.md) {
                        ForEach(rendered) { card in
                            Image(uiImage: card.image)
                                .resizable()
                                .aspectRatio(contentMode: .fit)
                                .frame(height: 220)
                                .clipShape(RoundedRectangle(cornerRadius: Metrics.Radius.sm, style: .continuous))
                                .overlay(RoundedRectangle(cornerRadius: Metrics.Radius.sm, style: .continuous).stroke(Palette.hairStrong, lineWidth: Metrics.hairline))
                                .accessibilityIdentifier("share.preview.\(card.name)")
                        }
                    }
                }
                .frame(height: 228)

                Spacer()

                if rendered.isEmpty {
                    Text(isRendering ? "share.rendering" : "share.pickOne")
                        .font(Typography.mono(11)).foregroundStyle(Palette.muted).frame(maxWidth: .infinity)
                } else {
                    ShareLink(items: rendered, subject: Text("share.subject"), message: Text("share.message")) { card in
                        SharePreview(card.name, image: Image(uiImage: card.image))
                    } label: {
                        Label { Text("share.cta.count \(rendered.count)") } icon: { Image(systemName: "square.and.arrow.up") }
                            .font(Typography.mono(11, weight: .semibold)).tracking(Typography.eyebrowTracking).textCase(.uppercase)
                            .foregroundStyle(Palette.abyss)
                            .frame(maxWidth: .infinity, minHeight: 48)
                            .background(Palette.teal, in: RoundedRectangle(cornerRadius: Metrics.Radius.sm, style: .continuous))
                    }
                    .accessibilityIdentifier("share.send")
                }
            }
            .padding(Metrics.Space.lg)
            .frame(maxWidth: 560)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
            .background(Palette.abyss.ignoresSafeArea())
            .navigationTitle(Text("share.title"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar { ToolbarItem(placement: .cancellationAction) { Button { dismiss() } label: { Text("common.cancel") } } }
        }
        .task { selected = preselected.intersection(available); render() }
        .onChange(of: selected) { _, _ in render() }
        .onChange(of: format) { _, _ in render() }
        .presentationDetents([.large])
    }

    private func render() {
        isRendering = true
        var out: [CardImage] = []
        for type in CardType.allCases where selected.contains(type) {
            let name = "pulsio-\(type.rawValue)-\(format.rawValue).png"
            let image: UIImage?
            switch type {
            case .pulsScore:
                image = scores.breakdown.flatMap { CardRenderer.render(PulsScoreCard(format: format, breakdown: $0, district: districts.district), format: format) }
            case .pulseResult:
                image = CardRenderer.render(PulseResultCard(format: format, rows: result.rows, district: districts.district, takenAt: result.takenAt ?? .now), format: format)
            case .report:
                image = report.flatMap { CardRenderer.render(ReportCard(format: format, report: $0), format: format) }
            }
            if let image { out.append(CardImage(name: name, image: image)) }
        }
        rendered = out
        isRendering = false
    }
}
