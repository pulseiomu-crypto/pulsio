import Foundation
import SwiftUI
import Testing
import UIKit
@testable import PulsIO

/// SPEC §16: every card is a real image at the exact Stories / WhatsApp pixel size, and every card carries
/// the way back. Rendered PNGs are written to `CARD_OUTPUT_DIR` (env) when set, for eyeballing.
@MainActor
struct ShareCardTests {
    private var breakdown: PulsScoreBreakdown {
        try! JSONDecoder().decode(PulsScoreBreakdown.self, from: Data(#"""
        {"score":75,"calculated_at":null,"verdict_key":"great","measured_count":3,"component_count":6,"components":[
          {"key":"weather","weight":30,"score":70,"basis":"measured","tone":"sky"},{"key":"safety","weight":25,"score":75,"basis":"measured","tone":"coral"},
          {"key":"beach","weight":20,"score":90,"basis":"derived","tone":"teal"},{"key":"traffic","weight":10,"score":70,"basis":"placeholder","tone":"amber"},
          {"key":"air","weight":8,"score":85,"basis":"placeholder","tone":"green"},{"key":"events","weight":7,"score":50,"basis":"measured","tone":"purple"}]}
        """#.utf8))
    }

    private var rows: [PulsePanelRow] {
        try! JSONDecoder().decode([PulsePanelRow].self, from: Data(#"""
        [{"key":"cyclone","group":"cyclone","kind":"status","label_key":"panel.row.cyclone","value_key":"mms.cyclone.none","detail_args":[],"tone":"green"},
         {"key":"ceb","group":"ceb","kind":"count","label_key":"panel.row.ceb","value":1,"unit":"outages","detail_key":"panel.detail.cebZone","detail_args":["Curepipe","19:00"],"tone":"amber"},
         {"key":"temperature","group":"weather","kind":"metric","label_key":"panel.row.temperature","value":22.8,"unit":"c","detail_args":[],"tone":"amber"},
         {"key":"humidity","group":"weather","kind":"metric","label_key":"panel.row.humidity","value":68,"unit":"pct","detail_args":[],"tone":"sky"},
         {"key":"wind","group":"weather","kind":"metric","label_key":"panel.row.wind","value":9,"unit":"kmh","detail_args":[],"tone":"sky"},
         {"key":"score","group":"score","kind":"metric","label_key":"panel.row.score","value":75,"unit":"score","detail_args":[],"tone":"green"},
         {"key":"fuel","group":"fuel","kind":"metric","label_key":"panel.row.fuel","value":70.65,"unit":"mur_l","detail_args":[],"tone":"green"},
         {"key":"sunset","group":"sun","kind":"computed","label_key":"panel.row.sunset","value":"18:03","unit":"time","detail_args":[],"tone":"amber"}]
        """#.utf8))
    }

    private var report: ReportCardModel {
        ReportCardModel(category: "Flooding", description: "Royal Road under 30 cm of water outside the Winners at Belle Rose — traffic diverted via Ebène.",
                        district: .plainesWilhems, confirmations: 4, createdAt: Date(timeIntervalSince1970: 1_789_300_000), symbol: "water.waves")
    }

    private func save(_ image: UIImage, _ name: String) {
        guard let dir = ProcessInfo.processInfo.environment["CARD_OUTPUT_DIR"], let data = image.pngData() else { return }
        try? data.write(to: URL(fileURLWithPath: dir).appendingPathComponent(name))
    }

    @Test(arguments: CardFormat.allCases)
    func everyCardRendersAtTheExactPixelSize(format: CardFormat) throws {
        let district = District.grandPort
        let cards: [(String, UIImage?)] = [
            ("pulsscore", CardRenderer.render(PulsScoreCard(format: format, breakdown: breakdown, district: district), format: format)),
            ("pulse-result", CardRenderer.render(PulseResultCard(format: format, rows: rows, district: district, takenAt: Date(timeIntervalSince1970: 1_789_300_000)), format: format)),
            ("report", CardRenderer.render(ReportCard(format: format, report: report), format: format)),
        ]
        for (name, image) in cards {
            let img = try #require(image, "\(name) failed to render")
            let px = CGSize(width: img.size.width * img.scale, height: img.size.height * img.scale)
            #expect(px == format.pixelSize, "\(name) \(format): \(px)")
            save(img, "card-\(name)-\(format.rawValue).png")
        }
    }

    @Test func cardLinksTagTheSourceCard() {
        #expect(CardLink.url(for: .pulsScore) == "https://pulsio.mu/?ref=card&t=pulsScore")
        #expect(CardLink.display == "pulsio.mu")
        #expect(QRCode.image(for: CardLink.url(for: .report), pixels: 180, foreground: .white, background: .black) != nil)
    }

    @Test func pngTransferIsARealImage() throws {
        let image = try #require(CardRenderer.render(PulsScoreCard(format: .square, breakdown: breakdown, district: nil), format: .square))
        let data = try #require(CardImage(name: "x.png", image: image).image.pngData())
        #expect(data.count > 20_000)
        #expect(Array(data.prefix(8)) == [0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A])
    }
}

struct PulsScoreVerdictTests {
    @Test(arguments: [(85, PulsScoreVerdict.perfect), (70, .great), (55, .decent), (40, .challenging), (25, .difficult), (0, .severe), (100, .perfect), (69, .decent)])
    func bandsMatchTheFunction(score: Int, verdict: PulsScoreVerdict) {
        #expect(PulsScoreVerdict.band(for: score) == verdict)
    }

    @Test func breakdownDecodes() throws {
        let b = try JSONDecoder().decode(PulsScoreBreakdown.self, from: Data(#"{"score":64,"verdict_key":"decent","measured_count":3,"component_count":6,"components":[{"key":"weather","weight":30,"score":70,"basis":"measured","tone":"sky"},{"key":"x","weight":1,"score":1,"basis":"mystery","tone":"sky"}]}"#.utf8))
        #expect(b.verdict == .decent && b.components[1].basis == .placeholder)   // unknown basis is never presented as measured
    }
}
