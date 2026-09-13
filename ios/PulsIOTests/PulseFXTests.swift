import CoreGraphics
import Foundation
import Testing
@testable import PulsIO

/// The ceremony is a pure function of time: these pin the choreography's shape so the web and native ports
/// can be compared frame-for-frame.
struct PulseFXChoreographyTests {
    typealias C = PulseFXChoreography

    @Test func phasesTileTheDurationInOrder() {
        let order: [C.Phase] = [C.Phases.camOut, C.Phases.gather, C.Phases.escape, C.Phases.stream, C.Phases.land,
                                C.Phases.wave, C.Phases.recall, C.Phases.ret, C.Phases.refill, C.Phases.camIn]
        #expect(order.count == 10)
        for (a, b) in zip(order, order.dropFirst()) { #expect(a.start <= b.start) }
        #expect(C.Phases.camIn.end == C.duration)
        #expect(C.duration == 7.45)
        #expect(C.revealAt == 1.88)
    }

    @Test func journeyGoesOutAndComesBack() {
        #expect(C.journey(0).u == 0)
        #expect(C.journey(1.88).u == 1)            // landed
        #expect(C.journey(3.0).vis == 0)           // the liquid is the wave now
        #expect(C.journey(C.Phases.ret.end).u == 0)  // back at the button
        #expect(C.journey(C.duration).spread == 1)
    }

    @Test func liquidIsConfinedUntilEscapeAndAgainAfterRefill() {
        #expect(C.clipRadius(0.5, inner: 33) == 33)
        #expect(C.clipRadius(2.0, inner: 33) == 0)
        #expect(C.clipRadius(C.duration, inner: 33) == 33)
    }

    @Test func frostClearsAcrossImpact() {
        #expect(C.frostOpacity(0) == 1)
        #expect(C.frostOpacity(1.87) == 1)
        #expect(C.frostOpacity(2.03) > 0 && C.frostOpacity(2.03) < 1)
        #expect(C.frostOpacity(2.18) == 0)
    }

    @Test func blobsAreDeterministic() {
        let a = C.blobsAt(1.234, from: CGPoint(x: 100, y: 700), to: CGPoint(x: 200, y: 300), calm: 1)
        let b = C.blobsAt(1.234, from: CGPoint(x: 100, y: 700), to: CGPoint(x: 200, y: 300), calm: 1)
        #expect(a.discs.count == 7)
        #expect(zip(a.discs, b.discs).allSatisfy { $0.center == $1.center && $0.radius == $1.radius })
    }

    @Test func waveLeadGrowsMonotonically() {
        var last: CGFloat = -1
        for i in 0...10 {
            let t = C.Phases.wave.start + (C.Phases.wave.end - C.Phases.wave.start) * Double(i) / 10
            let lead = C.waveLead(t, islandHeight: 500, landReach: 0.8)
            #expect(lead >= last); last = lead
        }
        #expect(C.waveLead(C.Phases.wave.end, islandHeight: 500, landReach: 0.8) == 400)
    }

    @Test func fitZoomStaysWithinTheClamp() {
        #expect(C.fitZoom(viewport: CGSize(width: 402, height: 874), bbox: PulseFXTerrain.bbox) <= 9.6)
        #expect(C.fitZoom(viewport: CGSize(width: 100, height: 100), bbox: PulseFXTerrain.bbox) == 8.1)
    }
}

struct PulseFXTerrainTests {
    /// A synthetic 256×366 heightmap: sea everywhere, one square island with a peak in the middle.
    private func syntheticImage() -> CGImage {
        let w = PulseFXTerrain.cols, h = PulseFXTerrain.rows
        var px = [UInt8](repeating: 0, count: w * h)
        for y in 120..<250 { for x in 60..<200 {
            let dx = Double(x - 130) / 70, dy = Double(y - 185) / 65
            px[y * w + x] = UInt8(max(0, min(255, (1 - (dx * dx + dy * dy).squareRoot()) * 255)))
        } }
        let ctx = CGContext(data: nil, width: w, height: h, bitsPerComponent: 8, bytesPerRow: w,
                            space: CGColorSpaceCreateDeviceGray(), bitmapInfo: CGImageAlphaInfo.none.rawValue)!
        px.withUnsafeBytes { ctx.data!.copyMemory(from: $0.baseAddress!, byteCount: w * h) }
        return ctx.makeImage()!
    }

    @Test func bakesMaskReliefAndReach() throws {
        let terrain = try #require(PulseFXTerrain(image: syntheticImage()))
        #expect(terrain.mask.width == 256 && terrain.mask.height == 366)
        #expect(terrain.relief.width == 256)
        #expect(terrain.landReach > 0 && terrain.landReach < 2)
        // Bilinear sampling in an on-screen rect: sea samples 0, the peak samples high.
        let r = CGRect(x: 0, y: 0, width: 256, height: 366)
        #expect(terrain.sampleHeight(at: CGPoint(x: 5, y: 5), in: r) == 0)
        #expect(terrain.sampleHeight(at: CGPoint(x: 130, y: 185), in: r) > 0.9)
        #expect(terrain.sampleHeight(at: CGPoint(x: -10, y: 50), in: r) == 0)   // outside the rect
    }

    @Test func bundledHeightmapLoads() throws {
        let terrain = try #require(PulseFXTerrain.loadFromBundle(), "MauritiusHeightmap data asset missing")
        #expect(terrain.heights.count == 256 * 366)
        #expect(terrain.landReach > 0.3 && terrain.landReach < 1.5)
    }
}

struct PulseStatusTests {
    @Test func decodesTheRPCRow() throws {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        let row = try decoder.decode(PulseStatus.self, from: Data(#"""
        {"paid_from":"quota","tier":"free","tier_name":"Explorer","pulses_per_day":1,"used_today":1,"quota_remaining":0,
         "topup_balance":2,"next_reset_at":"2026-09-13T20:00:00Z","can_pulse":true}
        """#.utf8))
        #expect(row.tier == .free && row.available == 2 && row.canPulse && !row.isUnlimited)
        let unlimited = try decoder.decode(PulseStatus.self, from: Data(#"""
        {"tier":"t2","tier_name":"Resident","pulses_per_day":null,"used_today":40,"quota_remaining":null,
         "topup_balance":0,"next_reset_at":"2026-09-13T20:00:00Z","can_pulse":true}
        """#.utf8))
        #expect(unlimited.isUnlimited && unlimited.available == nil)
    }

    @Test func pulseCodesMirrorTheContract() {
        #expect(PulseCode(rawValue: "P-103") == .spent)
        #expect(PulseCode(rawValue: "P-100") == .signIn)
        #expect(PulseCode(rawValue: "P-999") == nil)
    }
}
