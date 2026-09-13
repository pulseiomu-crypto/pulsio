import SwiftUI

/// The result panel: a generic renderer over the server's ordered rows (ARCHITECTURE §6/§7 test — a new
/// sourced row needs no new plumbing here). Dense data rows (RESTYLE Flag B).
struct PulsePanelView: View {
    @Environment(PulseResultStore.self) private var result
    @Environment(DistrictStore.self) private var districts
    var onTap: ((PulsePanelRow) -> Void)? = nil
    var onShare: (() -> Void)? = nil

    var body: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: 0) {
                header
                    .padding(.horizontal, Metrics.Space.lg)
                    .padding(.bottom, Metrics.Space.sm)
                ForEach(result.rows) { row in
                    PulsePanelRowView(row: row) { onTap?(row) }
                        .padding(.horizontal, Metrics.Space.lg)
                    Rectangle().fill(Palette.hair).frame(height: Metrics.hairline).padding(.leading, Metrics.Space.lg)
                }
                if result.rows.isEmpty {
                    Text(result.isLoading ? "panel.loading" : "panel.empty")
                        .font(Typography.mono(11))
                        .foregroundStyle(Palette.muted)
                        .frame(maxWidth: .infinity)
                        .padding(Metrics.Space.xl)
                }
            }
            .padding(.top, Metrics.Space.md)
            .padding(.bottom, Metrics.Space.xl)
        }
        .background(Palette.abyss)
    }

    private var header: some View {
        HStack(alignment: .firstTextBaseline) {
            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: Metrics.Space.sm) {
                    Circle().fill(Palette.coral).frame(width: 6, height: 6)
                    Eyebrow(text: "panel.eyebrow", tint: Palette.coral)
                }
                Text("panel.title")
                    .font(Typography.display(20))
                    .foregroundStyle(Palette.ink)
            }
            Spacer()
            VStack(alignment: .trailing, spacing: 2) {
                if let district = districts.district {
                    Text(district.label).font(Typography.mono(10)).foregroundStyle(Palette.muted)
                }
                if let takenAt = result.takenAt {
                    Text(takenAt, format: .dateTime.hour().minute()).font(Typography.mono(10)).foregroundStyle(Palette.muted2)
                }
            }
            if let onShare {
                Button(action: onShare) {
                    Image(systemName: "square.and.arrow.up").font(.system(size: 14, weight: .semibold)).foregroundStyle(Palette.teal)
                        .frame(width: 44, height: 44)
                }
                .buttonStyle(.plain)
                .accessibilityLabel(Text("share.cta"))
                .accessibilityIdentifier("panel.share")
            }
        }
        .accessibilityIdentifier("panel.header")
    }
}

/// One row: label · value+unit · detail — all from keys and codes, never per-row code.
struct PulsePanelRowView: View {
    let row: PulsePanelRow
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(alignment: .firstTextBaseline, spacing: Metrics.Space.md) {
                Circle().fill(PanelTone.color(row.tone)).frame(width: 6, height: 6).alignmentGuide(.firstTextBaseline) { $0[.bottom] - 1 }
                VStack(alignment: .leading, spacing: 3) {
                    Text(LocalizedStringResource(stringLiteral: row.labelKey))
                        .font(Typography.mono(10, weight: .medium))
                        .tracking(0.14)
                        .textCase(.uppercase)
                        .foregroundStyle(Palette.muted)
                    if let detail = PanelFormat.detail(row) {
                        Text(detail)
                            .font(Typography.body(12))
                            .foregroundStyle(Palette.muted)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    if !row.items.isEmpty {
                        ForEach(row.items, id: \.self) { item in
                            Text(item).font(Typography.body(12)).foregroundStyle(Palette.ink)
                        }
                    }
                }
                Spacer(minLength: Metrics.Space.md)
                Text(PanelFormat.value(row))
                    .font(row.kind == .status ? Typography.body(13, weight: .semibold) : Typography.display(18, weight: .bold))
                    .foregroundStyle(PanelTone.color(row.tone))
                    .multilineTextAlignment(.trailing)
                    .fixedSize(horizontal: false, vertical: true)
                    .frame(maxWidth: 160, alignment: .trailing)
                if row.tap != nil {
                    Image(systemName: "chevron.right").font(.system(size: 11, weight: .semibold)).foregroundStyle(Palette.muted2)
                }
            }
            .padding(.vertical, Metrics.Space.md)
            .frame(minHeight: 44)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .disabled(row.tap == nil)
        .accessibilityIdentifier("panel.row.\(row.key)")
    }
}

/// Semantic colour token (SPEC §24) → palette.
enum PanelTone {
    static func color(_ token: String) -> Color {
        switch token {
        case "sky": Palette.sky
        case "amber": Palette.amber
        case "coral": Palette.coral
        case "green": Palette.green
        case "purple": Palette.purple
        case "teal": Palette.teal
        case "transport": Palette.transport
        default: Palette.muted
        }
    }
}

/// Values and details from unit codes and localisation keys. The only formatting knowledge on the client.
enum PanelFormat {
    static func value(_ row: PulsePanelRow) -> String {
        if let key = row.valueKey { return String(localized: LocalizedStringResource(stringLiteral: key)) }
        guard let value = row.value else { return "—" }
        let text: String
        switch value {
        case .text(let s): text = s
        case .number(let n):
            let digits = (row.unit == "c" || row.unit == "uv" || row.unit == "mur_l") ? 1 : 0
            text = n.formatted(.number.precision(.fractionLength(row.unit == "mur_l" ? 2 : (n == n.rounded() ? 0 : digits))))
        }
        switch row.unit {
        case "c": return text + "°"
        case "pct": return text + "%"
        case "kmh": return text + " " + String(localized: "unit.kmh")
        case "uv": return text
        case "score": return text + "/100"
        case "mur_l": return "MUR " + text + String(localized: "unit.perLitre")
        case "outages", "reports", "events": return text
        default: return text
        }
    }

    static func detail(_ row: PulsePanelRow) -> String? {
        guard let key = row.detailKey else { return nil }
        let args = row.detailArgs
        // Keys are declared with positional %@ placeholders in the catalog; fill up to three.
        let format = String(localized: LocalizedStringResource(stringLiteral: key))
        let a = args.count > 0 ? args[0] : "", b = args.count > 1 ? args[1] : "", c = args.count > 2 ? args[2] : ""
        return String(format: format, locale: .current, a, b, c)
    }
}
