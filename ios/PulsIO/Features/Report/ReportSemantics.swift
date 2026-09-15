import SwiftUI

/// Category → symbol and label. Colour: reports are warnings (amber) unless confirmed (coral for dangers).
extension ReportCategory {
    var symbol: String {
        switch self {
        case .powerCut: "bolt.slash.fill"
        case .waterCut: "drop.slash"
        case .accident: "car.side.rear.and.collision.and.car.side.front"
        case .hazard: "exclamationmark.triangle.fill"
        case .flood: "water.waves"
        case .traffic: "car.2.fill"
        case .jellyfish: "figure.open.water.swim"
        case .event: "party.popper.fill"
        case .infrastructure: "wrench.and.screwdriver.fill"
        case .other: "ellipsis.circle.fill"
        }
    }

    var label: LocalizedStringResource {
        switch self {
        case .powerCut: "report.category.power_cut"
        case .waterCut: "report.category.water_cut"
        case .accident: "report.category.accident"
        case .hazard: "report.category.hazard"
        case .flood: "report.category.flood"
        case .traffic: "report.category.traffic"
        case .jellyfish: "report.category.jellyfish"
        case .event: "report.category.event"
        case .infrastructure: "report.category.infrastructure"
        case .other: "report.category.other"
        }
    }
}

extension ReportStatus {
    var label: LocalizedStringResource {
        switch self {
        case .pending: "report.status.pending"
        case .unconfirmed: "report.status.unconfirmed"
        case .confirmed: "report.status.confirmed"
        case .hidden: "report.status.hidden"
        case .removed: "report.status.removed"
        case .expired: "report.status.expired"
        }
    }
}

extension Report {
    /// Amber while unconfirmed, coral once the community has confirmed it; muted while awaiting review.
    var tint: Color {
        switch status {
        case .confirmed: Palette.coral
        case .unconfirmed: Palette.amber
        default: Palette.muted
        }
    }
    var tintHex: String {
        switch status {
        case .confirmed: Palette.Hex.string(Palette.Hex.coral)
        case .unconfirmed: Palette.Hex.string(Palette.Hex.amber)
        default: Palette.Hex.string(Palette.Hex.muted)
        }
    }
    static let markerPrefix = "report-"
    var markerID: String { "\(Self.markerPrefix)\(id)" }
}
