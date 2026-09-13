import Foundation
import Testing
@testable import PulsIO

/// The panel row contract: decode exactly what pulse_snapshot() emits, render values from unit codes.
struct PulsePanelRowTests {
    private let sample = #"""
    [{"key":"cyclone","group":"cyclone","kind":"status","label_key":"panel.row.cyclone","value_key":"mms.cyclone.none","detail_key":null,"detail_args":[],"tone":"green","tap":"map"},
     {"key":"ceb","group":"ceb","kind":"count","label_key":"panel.row.ceb","value":1,"unit":"outages","detail_key":"panel.detail.cebZone","detail_args":["Curepipe","19:00"],"tone":"amber","tap":"map"},
     {"key":"temperature","group":"weather","kind":"metric","label_key":"panel.row.temperature","value":18.3,"unit":"c","detail_key":"panel.detail.feelsLike","detail_args":["18","Clouds","Curepipe"],"tone":"amber"},
     {"key":"uv","group":"weather","kind":"metric","label_key":"panel.row.uv","value":null,"unit":"uv","detail_key":null,"detail_args":[],"tone":"green"},
     {"key":"fuel","group":"fuel","kind":"metric","label_key":"panel.row.fuel","value":70.65,"unit":"mur_l","detail_key":"panel.detail.diesel","detail_args":[71.25],"tone":"green"},
     {"key":"events","group":"events","kind":"list","label_key":"panel.row.events","value":2,"unit":"events","items":["Port Louis Bazaar","Regatta"],"detail_key":null,"detail_args":[],"tone":"purple","tap":"map"},
     {"key":"sunset","group":"sun","kind":"computed","label_key":"panel.row.sunset","value":null,"unit":"time","detail_key":null,"detail_args":[],"tone":"amber"}]
    """#

    @Test func decodesTheServerShapeInOrder() throws {
        let rows = try JSONDecoder().decode([PulsePanelRow].self, from: Data(sample.utf8))
        #expect(rows.map(\.key) == ["cyclone", "ceb", "temperature", "uv", "fuel", "events", "sunset"])
        #expect(rows[0].kind == .status && rows[0].valueKey == "mms.cyclone.none")
        #expect(rows[1].value == .number(1) && rows[1].detailArgs == ["Curepipe", "19:00"])
        #expect(rows[4].detailArgs == ["71.25"])              // numeric arg rendered as text
        #expect(rows[5].items == ["Port Louis Bazaar", "Regatta"])
        #expect(rows[6].kind == .computed && rows[6].value == nil)
    }

    @Test func formatsValuesFromUnitCodes() throws {
        let rows = try JSONDecoder().decode([PulsePanelRow].self, from: Data(sample.utf8))
        #expect(PanelFormat.value(rows[0]) == "No cyclone warning in force")   // MMS wording, verbatim
        #expect(PanelFormat.value(rows[1]) == "1")
        #expect(PanelFormat.value(rows[2]) == "18.3°")
        #expect(PanelFormat.value(rows[3]) == "—")                              // null value never crashes
        #expect(PanelFormat.value(rows[4]) == "MUR 70.65/L")
        #expect(PanelFormat.detail(rows[1]) == "Nearest: Curepipe · back by 19:00")
        #expect(PanelFormat.detail(rows[2]) == "Feels like 18° · Clouds · Curepipe")
        #expect(PanelFormat.detail(rows[0]) == nil)
    }

    @Test func unknownToneFallsBackToMuted() {
        #expect(PanelTone.color("nonsense") == PanelTone.color("muted"))
        #expect(PanelTone.color("coral") != PanelTone.color("green"))
    }
}

struct SunCalculatorTests {
    @Test func portLouisSunsetOnAKnownDate() throws {
        var cal = Calendar(identifier: .gregorian)
        cal.timeZone = SunCalculator.mauritius
        let noon = try #require(cal.date(from: DateComponents(year: 2026, month: 9, day: 13, hour: 12)))
        let sunset = try #require(SunCalculator.sunset(on: noon, latitude: -20.1609, longitude: 57.5012, timeZone: SunCalculator.mauritius))
        // Independent NOAA-style calculation gives 18:05 MUT (14:05 UTC); allow a few minutes.
        let expected = try #require(cal.date(from: DateComponents(year: 2026, month: 9, day: 13, hour: 18, minute: 5)))
        #expect(abs(sunset.timeIntervalSince(expected)) < 4 * 60)
    }

    @Test func summerSunsetIsLater() throws {
        var cal = Calendar(identifier: .gregorian)
        cal.timeZone = SunCalculator.mauritius
        let sep = try #require(SunCalculator.sunset(on: cal.date(from: DateComponents(year: 2026, month: 9, day: 13, hour: 12))!, latitude: -20.16, longitude: 57.5, timeZone: SunCalculator.mauritius))
        let dec = try #require(SunCalculator.sunset(on: cal.date(from: DateComponents(year: 2026, month: 12, day: 21, hour: 12))!, latitude: -20.16, longitude: 57.5, timeZone: SunCalculator.mauritius))
        #expect(cal.component(.hour, from: dec) * 60 + cal.component(.minute, from: dec) > cal.component(.hour, from: sep) * 60 + cal.component(.minute, from: sep))
    }
}
