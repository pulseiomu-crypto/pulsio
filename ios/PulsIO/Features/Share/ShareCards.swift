import SwiftUI
import UIKit

/// SPEC §16: three card types, two formats, real images. Every card carries the PulsIO name and a way back
/// (link + QR) — a card forwarded with no way back is wasted reach.
enum CardType: String, CaseIterable, Identifiable, Sendable {
    case pulseResult, pulsScore, report
    var id: String { rawValue }
    var label: LocalizedStringResource {
        switch self {
        case .pulseResult: "share.card.pulseResult"
        case .pulsScore: "share.card.pulsScore"
        case .report: "share.card.report"
        }
    }
}

enum CardFormat: String, CaseIterable, Identifiable, Sendable {
    /// Instagram Stories 1080×1920.
    case stories
    /// WhatsApp-shaped 1080×1080.
    case square
    var id: String { rawValue }
    /// Rendered at 3× so points × 3 = pixels exactly.
    var pointSize: CGSize {
        switch self {
        case .stories: CGSize(width: 360, height: 640)
        case .square: CGSize(width: 360, height: 360)
        }
    }
    var pixelSize: CGSize { CGSize(width: pointSize.width * 3, height: pointSize.height * 3) }
    var label: LocalizedStringResource {
        switch self {
        case .stories: "share.format.stories"
        case .square: "share.format.square"
        }
    }
}

/// The way back. `t` tags which card brought them.
enum CardLink {
    static let base = "https://pulsio.mu"
    static func url(for type: CardType) -> String { "\(base)/?ref=card&t=\(type.rawValue)" }
    static let display = "pulsio.mu"
}

/// What a report card shows — the `pulsio_reports` shape it will be fed from (SPEC §11); reports aren't
/// built yet, so today this is fed by the debug sample only.
struct ReportCardModel: Sendable, Equatable {
    let category: String
    let description: String
    let district: District?
    let confirmations: Int
    let createdAt: Date
    let symbol: String
}

// MARK: - Chrome

/// The frame every card shares: atmosphere, wordmark + LIVE date line at the top, link + QR at the bottom.
struct CardChrome<Content: View>: View {
    let format: CardFormat
    let type: CardType
    let district: District?
    let date: Date
    @ViewBuilder let content: () -> Content

    var body: some View {
        let s = format.pointSize
        ZStack(alignment: .top) {
            Palette.abyss
            RadialGradient(colors: [Palette.teal.opacity(0.10), .clear], center: UnitPoint(x: 0.5, y: 0.15), startRadius: 0, endRadius: s.width * 0.9)
            RadialGradient(colors: [Palette.blue.opacity(0.08), .clear], center: UnitPoint(x: 0.85, y: 0.9), startRadius: 0, endRadius: s.width * 0.7)
            Scanlines()
            VStack(spacing: 0) {
                header.padding(.horizontal, 24).padding(.top, format == .stories ? 44 : 24)
                Spacer(minLength: 0)
                content().padding(.horizontal, 24)
                Spacer(minLength: 0)
                footer.padding(.horizontal, 24).padding(.bottom, format == .stories ? 40 : 22)
            }
        }
        .frame(width: s.width, height: s.height)
        .clipped()
    }

    private var header: some View {
        HStack(alignment: .center) {
            HStack(spacing: 8) {
                BrandMark(size: 28)
                Wordmark(size: 22)
            }
            Spacer()
            VStack(alignment: .trailing, spacing: 2) {
                HStack(spacing: 5) {
                    Circle().fill(Palette.coral).frame(width: 5, height: 5)
                    Text("panel.eyebrow").font(Typography.mono(9, weight: .semibold)).tracking(0.2).textCase(.uppercase).foregroundStyle(Palette.coral)
                }
                Text(date.formatted(.dateTime.day().month(.abbreviated).hour().minute()))
                    .font(Typography.mono(9)).foregroundStyle(Palette.muted)
                if let district { Text(district.label).font(Typography.mono(9)).foregroundStyle(Palette.muted2) }
            }
        }
    }

    private var footer: some View {
        HStack(alignment: .center, spacing: 14) {
            VStack(alignment: .leading, spacing: 3) {
                Text("share.footer.cta").font(Typography.body(12, weight: .medium)).foregroundStyle(Palette.ink)
                Text(verbatim: CardLink.display).font(Typography.mono(13, weight: .semibold)).tracking(0.1).foregroundStyle(Palette.teal)
                Text("share.footer.tagline").font(Typography.mono(8)).tracking(0.14).textCase(.uppercase).foregroundStyle(Palette.muted2)
            }
            Spacer()
            if let qr = QRCode.image(for: CardLink.url(for: type), pixels: 180, foreground: UIColor(Palette.bone), background: UIColor(Palette.abyss)) {
                Image(uiImage: qr)
                    .interpolation(.none)
                    .resizable()
                    .frame(width: 56, height: 56)
                    .clipShape(RoundedRectangle(cornerRadius: 6, style: .continuous))
                    .overlay(RoundedRectangle(cornerRadius: 6, style: .continuous).stroke(Palette.hairStrong, lineWidth: 0.5))
            }
        }
        .padding(14)
        .background(Palette.deep.opacity(0.85), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 14, style: .continuous).stroke(Palette.hairStrong, lineWidth: 0.5))
    }
}

// MARK: - The three cards

struct PulsScoreCard: View {
    let format: CardFormat
    let breakdown: PulsScoreBreakdown
    let district: District?

    var body: some View {
        CardChrome(format: format, type: .pulsScore, district: district, date: breakdown.calculatedAt ?? .now) {
            VStack(spacing: format == .stories ? 22 : 12) {
                Eyebrow(text: "pulsscore.card.eyebrow", tint: Palette.teal)
                PulsScoreRing(breakdown: breakdown, lineWidth: format == .stories ? 18 : 14)
                    .frame(width: format == .stories ? 236 : 150, height: format == .stories ? 236 : 150)
                Text(breakdown.verdict.label)
                    .font(Typography.display(format == .stories ? 26 : 20))
                    .foregroundStyle(Palette.ink)
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)
                if format == .stories {
                    HStack(spacing: 8) {
                        ForEach(breakdown.components) { c in
                            VStack(spacing: 3) {
                                Text(String(c.score)).font(Typography.display(15)).foregroundStyle(PanelTone.color(c.tone)).monospacedDigit()
                                Text(c.label).font(Typography.mono(7)).textCase(.uppercase).foregroundStyle(Palette.muted).lineLimit(1)
                                Rectangle().fill(PanelTone.color(c.tone).opacity(c.basis == .measured ? 1 : 0.4)).frame(width: 22, height: 2)
                            }
                            .frame(maxWidth: .infinity)
                        }
                    }
                    Text("pulsscore.honesty \(breakdown.measuredCount) \(breakdown.componentCount)")
                        .font(Typography.mono(8)).foregroundStyle(Palette.muted2).multilineTextAlignment(.center)
                }
            }
        }
    }
}

struct PulseResultCard: View {
    let format: CardFormat
    let rows: [PulsePanelRow]
    let district: District?
    let takenAt: Date

    var body: some View {
        CardChrome(format: format, type: .pulseResult, district: district, date: takenAt) {
            VStack(alignment: .leading, spacing: 0) {
                Eyebrow(text: "share.pulse.eyebrow", tint: Palette.teal).padding(.bottom, 8)
                Text("panel.title").font(Typography.display(format == .stories ? 26 : 20)).foregroundStyle(Palette.ink).padding(.bottom, 8)
                ForEach(Array(rows.prefix(format == .stories ? 7 : 4))) { row in
                    HStack(alignment: .firstTextBaseline, spacing: 10) {
                        Circle().fill(PanelTone.color(row.tone)).frame(width: 5, height: 5)
                        Text(LocalizedStringResource(stringLiteral: row.labelKey))
                            .font(Typography.mono(9)).tracking(0.12).textCase(.uppercase).foregroundStyle(Palette.muted)
                        Spacer()
                        Text(PanelFormat.value(row))
                            .font(row.kind == .status ? Typography.body(11, weight: .semibold) : Typography.display(15))
                            .foregroundStyle(PanelTone.color(row.tone)).lineLimit(2).multilineTextAlignment(.trailing)
                    }
                    .padding(.vertical, format == .stories ? 8 : 5)
                    Rectangle().fill(Palette.hair).frame(height: 0.5)
                }
            }
            .padding(16)
            .background(Palette.deep.opacity(0.6), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: 14, style: .continuous).stroke(Palette.hairStrong, lineWidth: 0.5))
        }
    }
}

struct ReportCard: View {
    let format: CardFormat
    let report: ReportCardModel

    var body: some View {
        CardChrome(format: format, type: .report, district: report.district, date: report.createdAt) {
            VStack(alignment: .leading, spacing: 12) {
                HStack(spacing: 8) {
                    Image(systemName: report.symbol).font(.system(size: 14, weight: .semibold)).foregroundStyle(Palette.amber)
                    Eyebrow(text: "share.report.eyebrow", tint: Palette.amber)
                }
                Text(report.category).font(Typography.display(format == .stories ? 26 : 20)).foregroundStyle(Palette.ink)
                Text(report.description)
                    .font(Typography.body(format == .stories ? 15 : 12)).lineSpacing(3).foregroundStyle(Palette.ink.opacity(0.88))
                    .lineLimit(format == .stories ? 6 : 3).fixedSize(horizontal: false, vertical: true)
                HStack(spacing: 6) {
                    Image(systemName: "checkmark.seal.fill").foregroundStyle(Palette.green).font(.system(size: 11))
                    Text("share.report.confirmed \(report.confirmations)").font(Typography.mono(9)).foregroundStyle(Palette.muted)
                }
            }
            .padding(16)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Palette.deep.opacity(0.6), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: 14, style: .continuous).stroke(Palette.amber.opacity(0.35), lineWidth: 0.5))
        }
    }
}

// MARK: - Rendering & transfer

/// Renders a card view to a PNG at the format's exact pixel size (points × 3).
@MainActor
enum CardRenderer {
    static func render<V: View>(_ view: V, format: CardFormat) -> UIImage? {
        let renderer = ImageRenderer(content: view.environment(\.colorScheme, .dark))
        renderer.scale = 3
        renderer.proposedSize = ProposedViewSize(format.pointSize)
        return renderer.uiImage
    }
}

/// A rendered card, shareable as a PNG file.
struct CardImage: Transferable, Identifiable {
    let id = UUID()
    let name: String
    let image: UIImage

    static var transferRepresentation: some TransferRepresentation {
        DataRepresentation(exportedContentType: .png) { card in card.image.pngData() ?? Data() }
            .suggestedFileName { $0.name }
    }
}

/// A "your report may be featured" notice for the submission flow (SPEC §16), ready for the report form.
struct ReportFeatureNotice: View {
    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: Metrics.Space.sm) {
            Image(systemName: "camera.badge.ellipsis").foregroundStyle(Palette.teal).font(.system(size: 11, weight: .semibold))
            Text("report.submit.mayBeFeatured")
                .font(Typography.body(12)).foregroundStyle(Palette.muted).fixedSize(horizontal: false, vertical: true)
        }
        .accessibilityIdentifier("report.featureNotice")
    }
}
