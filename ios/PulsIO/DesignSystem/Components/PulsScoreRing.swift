import SwiftUI

/// The weighted-arc ring: one circle split into six arcs whose lengths ARE the component weights
/// (30/25/20/10/8/7), each filled to its own score in its semantic colour. Basis is drawn, not captioned:
/// measured = solid; derived = solid at reduced opacity; placeholder = dashed. The ring is the data.
struct PulsScoreRing: View {
    let breakdown: PulsScoreBreakdown?
    var lineWidth: CGFloat = 14
    var gapDegrees: Double = 3
    /// Content drawn in the middle (score + verdict).
    var showsCentre = true

    var body: some View {
        ZStack {
            Canvas { context, size in
                let centre = CGPoint(x: size.width / 2, y: size.height / 2)
                let radius = min(size.width, size.height) / 2 - lineWidth / 2
                let components = breakdown?.components ?? PulsScoreRing.placeholderComponents
                let totalWeight = Double(components.reduce(0) { $0 + $1.weight })
                let usable = 360 - gapDegrees * Double(components.count)
                var start = -90.0
                for c in components {
                    let span = usable * Double(c.weight) / totalWeight
                    let track = Path { p in p.addArc(center: centre, radius: radius, startAngle: .degrees(start), endAngle: .degrees(start + span), clockwise: false) }
                    context.stroke(track, with: .color(Palette.hair), style: StrokeStyle(lineWidth: lineWidth, lineCap: .butt))
                    if let breakdown, breakdown.score >= 0 {
                        let fillSpan = span * Double(min(100, max(0, c.score))) / 100
                        let fill = Path { p in p.addArc(center: centre, radius: radius, startAngle: .degrees(start), endAngle: .degrees(start + fillSpan), clockwise: false) }
                        let colour = PanelTone.color(c.tone)
                        switch c.basis {
                        case .measured:
                            context.stroke(fill, with: .color(colour), style: StrokeStyle(lineWidth: lineWidth, lineCap: .butt))
                        case .derived:
                            context.stroke(fill, with: .color(colour.opacity(0.7)), style: StrokeStyle(lineWidth: lineWidth, lineCap: .butt))
                        case .placeholder:
                            context.stroke(fill, with: .color(colour.opacity(0.75)), style: StrokeStyle(lineWidth: lineWidth, lineCap: .butt, dash: [4, 3]))
                        }
                    }
                    start += span + gapDegrees
                }
            }
            if showsCentre {
                VStack(spacing: 2) {
                    Text(breakdown.map { String($0.score) } ?? "—")
                        .font(Typography.display(52, weight: .heavy))
                        .foregroundStyle(Palette.ink)
                        .monospacedDigit()
                    Text("pulsscore.outOf")
                        .font(Typography.mono(10))
                        .tracking(0.14)
                        .foregroundStyle(Palette.muted2)
                }
            }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(Text("pulsscore.title"))
        .accessibilityValue(Text(breakdown.map { "\($0.score)" } ?? "—"))
    }

    /// Empty tracks with the contract's weights, for the loading state.
    static let placeholderComponents: [PulsScoreBreakdown.Component] = [
        .init(key: "weather", weight: 30, score: 0, basis: .measured, tone: "sky"), .init(key: "safety", weight: 25, score: 0, basis: .measured, tone: "coral"),
        .init(key: "beach", weight: 20, score: 0, basis: .derived, tone: "teal"), .init(key: "traffic", weight: 10, score: 0, basis: .placeholder, tone: "amber"),
        .init(key: "air", weight: 8, score: 0, basis: .placeholder, tone: "green"), .init(key: "events", weight: 7, score: 0, basis: .measured, tone: "purple"),
    ]
}

extension PulsScoreBreakdown.Component {
    var label: LocalizedStringResource {
        switch key {
        case "weather": "pulsscore.component.weather"
        case "safety": "pulsscore.component.safety"
        case "beach": "pulsscore.component.beach"
        case "traffic": "pulsscore.component.traffic"
        case "air": "pulsscore.component.air"
        case "events": "pulsscore.component.events"
        default: LocalizedStringResource(stringLiteral: key)
        }
    }

    var basisLabel: LocalizedStringResource {
        switch basis {
        case .measured: "pulsscore.basis.measured"
        case .derived: "pulsscore.basis.derived"
        case .placeholder: "pulsscore.basis.placeholder"
        }
    }
}
