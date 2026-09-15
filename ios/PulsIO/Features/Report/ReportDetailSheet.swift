import CoreLocation
import SwiftUI

/// A report from the map: the (blurred) photo, what/where/when, confirmations, and the actions Apple's UGC
/// rules require to actually work — confirm (within 2 km, on-device), flag, block the author, delete my own.
struct ReportDetailSheet: View {
    @Environment(ReportStore.self) private var reports
    @Environment(SessionStore.self) private var session
    @Environment(AccessGate.self) private var gate
    @Environment(DistrictStore.self) private var districts
    @Environment(\.dismiss) private var dismiss
    let reportID: Int64

    @State private var isWorking = false
    @State private var errorKey: LocalizedStringResource?
    @State private var showFlagReasons = false
    @State private var showBlockConfirm = false
    @State private var showDeleteConfirm = false
    @State private var showShare = false
    @State private var tooFar = false

    private var report: Report? { reports.report(id: reportID) }

    var body: some View {
        NavigationStack {
            if let report {
                ScrollView {
                    VStack(alignment: .leading, spacing: Metrics.Space.lg) {
                        if let url = reports.photoURL(for: report) {
                            AsyncImage(url: url) { phase in
                                switch phase {
                                case .success(let image): image.resizable().aspectRatio(contentMode: .fit)
                                case .failure: Rectangle().fill(Palette.deep).overlay(Image(systemName: "photo").foregroundStyle(Palette.muted2)).aspectRatio(4/3, contentMode: .fit)
                                default: Rectangle().fill(Palette.deep).aspectRatio(4/3, contentMode: .fit).overlay(ProgressView().tint(Palette.teal))
                                }
                            }
                            .clipShape(RoundedRectangle(cornerRadius: Metrics.Radius.md, style: .continuous))
                            .accessibilityIdentifier("reportDetail.photo")
                        }
                        HStack(spacing: Metrics.Space.sm) {
                            Image(systemName: report.category.symbol).foregroundStyle(report.tint)
                            Text(report.category.label).font(Typography.display(20)).foregroundStyle(Palette.ink)
                            Spacer()
                            Text(report.status.label)
                                .font(Typography.mono(9, weight: .semibold)).tracking(0.14).textCase(.uppercase)
                                .foregroundStyle(report.tint)
                                .padding(.horizontal, Metrics.Space.sm).padding(.vertical, 4)
                                .background(report.tint.opacity(0.12), in: Capsule())
                                .accessibilityIdentifier("reportDetail.status")
                        }
                        if let description = report.description {
                            Text(description).font(Typography.body(15)).foregroundStyle(Palette.ink.opacity(0.9)).fixedSize(horizontal: false, vertical: true)
                        }
                        HStack(spacing: 0) {
                            if let district = report.district { Text(district.label).foregroundStyle(Palette.muted) ; Text(verbatim: " · ").foregroundStyle(Palette.muted2) }
                            if let at = report.createdAt { Text(at, format: .relative(presentation: .named)).foregroundStyle(Palette.muted2) }
                        }
                        .font(Typography.mono(10))
                        HStack(spacing: Metrics.Space.sm) {
                            Image(systemName: "checkmark.seal.fill").foregroundStyle(report.status == .confirmed ? Palette.green : Palette.muted2)
                            Text("report.detail.confirmations \(report.confirmations) \(ReportRules.confirmationsToConfirm)").font(Typography.mono(11)).foregroundStyle(Palette.muted)
                        }
                        .accessibilityIdentifier("reportDetail.confirmations")
                        if report.status == .pending {
                            Text("report.detail.pendingNote").font(Typography.body(13)).foregroundStyle(Palette.amber).fixedSize(horizontal: false, vertical: true)
                        }

                        if let errorKey { Text(errorKey).font(Typography.mono(11)).foregroundStyle(Palette.coral).accessibilityIdentifier("reportDetail.error") }

                        VStack(spacing: Metrics.Space.md) {
                            if reports.isMine(report) {
                                Button(role: .destructive) { showDeleteConfirm = true } label: { Label { Text("report.action.delete") } icon: { Image(systemName: "trash") } }
                                    .buttonStyle(.destructiveOutline)
                                    .accessibilityIdentifier("reportDetail.delete")
                            } else if report.status.isLive {
                                Button { confirmTapped(report) } label: { Label { Text("report.action.confirm") } icon: { Image(systemName: "checkmark") } }
                                    .buttonStyle(.prominent)
                                    .disabled(report.confirmedBy.contains(session.user?.id ?? UUID()))
                                    .accessibilityIdentifier("reportDetail.confirm")
                                if tooFar {
                                    Text("report.error.tooFar").font(Typography.mono(10)).foregroundStyle(Palette.amber).accessibilityIdentifier("reportDetail.tooFar")
                                }
                                HStack(spacing: Metrics.Space.md) {
                                    Button { gate.perform(.confirmReport) { showFlagReasons = true } } label: { Label { Text("report.action.flag") } icon: { Image(systemName: "flag") } }
                                        .buttonStyle(.outline)
                                        .accessibilityIdentifier("reportDetail.flag")
                                    Button { gate.perform(.confirmReport) { showBlockConfirm = true } } label: { Label { Text("report.action.block") } icon: { Image(systemName: "hand.raised") } }
                                        .buttonStyle(.destructiveOutline)
                                        .accessibilityIdentifier("reportDetail.block")
                                }
                            }
                            if report.status.isLive {
                                Button { showShare = true } label: { Label { Text("share.cta") } icon: { Image(systemName: "square.and.arrow.up") } }
                                    .buttonStyle(.outline)
                            }
                        }
                    }
                    .padding(Metrics.Space.lg)
                    .frame(maxWidth: 560)
                    .frame(maxWidth: .infinity)
                }
                .background(Palette.abyss.ignoresSafeArea())
                .navigationTitle(Text("report.detail.title"))
                .navigationBarTitleDisplayMode(.inline)
                .toolbar { ToolbarItem(placement: .confirmationAction) { Button { dismiss() } label: { Text("common.done") } } }
                .disabled(isWorking)
                .confirmationDialog(Text("report.flag.title"), isPresented: $showFlagReasons, titleVisibility: .visible) {
                    ForEach(["wrong_category", "not_real", "inappropriate", "people", "spam"], id: \.self) { reason in
                        Button { Task { await run { await reports.flag(report, reason: reason) } } } label: { Text(LocalizedStringResource(stringLiteral: "report.flag.reason.\(reason)")) }
                    }
                    Button(role: .cancel) {} label: { Text("common.cancel") }
                }
                .confirmationDialog(Text("report.block.title"), isPresented: $showBlockConfirm, titleVisibility: .visible) {
                    Button(role: .destructive) { Task { await run { await reports.blockReporter(of: report) }; dismiss() } } label: { Text("report.block.confirm") }
                    Button(role: .cancel) {} label: { Text("common.cancel") }
                } message: { Text("report.block.body") }
                .confirmationDialog(Text("report.delete.title"), isPresented: $showDeleteConfirm, titleVisibility: .visible) {
                    Button(role: .destructive) { Task { await run { await reports.deleteOwn(report) }; dismiss() } } label: { Text("report.action.delete") }
                    Button(role: .cancel) {} label: { Text("common.cancel") }
                }
                .sheet(isPresented: $showShare) {
                    ShareCardsSheet(preselected: [.report], report: ReportCardModel(
                        category: String(localized: report.category.label), description: report.description ?? "", district: report.district,
                        confirmations: report.confirmations, createdAt: report.createdAt ?? .now, symbol: report.category.symbol))
                }
            } else {
                Text("report.detail.gone").font(Typography.mono(11)).foregroundStyle(Palette.muted).padding()
                    .frame(maxWidth: .infinity, maxHeight: .infinity).background(Palette.abyss.ignoresSafeArea())
            }
        }
        .presentationDetents([.medium, .large])
        .presentationDragIndicator(.visible)
    }

    /// Confirm: the 2 km check happens here, on the device; only the confirm action reaches the server.
    private func confirmTapped(_ report: Report) {
        gate.perform(.confirmReport) {
            tooFar = false
            guard let here = await districts.currentFix() else { errorKey = "report.error.needLocation"; return }
            guard report.isWithinConfirmRadius(of: here) else { tooFar = true; return }
            await run { await reports.confirm(report) }
        }
    }

    private func run(_ work: () async -> ReportFailure?) async {
        isWorking = true
        errorKey = nil
        defer { isWorking = false }
        switch await work() {
        case nil: break
        case .code(let code)?: errorKey = code.messageKey
        case .other?: errorKey = "report.error.generic"
        }
    }
}
