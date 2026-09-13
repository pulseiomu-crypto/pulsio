import CoreGraphics
import Foundation

/// The pulse ceremony's timing and motion, ported 1:1 from the web `PulseFX` module. Everything here is a
/// pure function of elapsed seconds `t` — seek to any t and you get exactly that frame. No randomness:
/// blob parameters derive from their index, so the animation is reproducible on both clients.
enum PulseFXChoreography {
    typealias Phase = (start: Double, end: Double)

    // ── Choreography, in seconds ─────────────────────────────────────────
    enum Phases {
        static let camOut: Phase = (0.00, 1.00)   // map pulls back — the app going quiet
        static let gather: Phase = (0.10, 0.78)   // blobs stop drifting and converge
        static let escape: Phase = (0.78, 1.08)   // the mass breaks past the bezel
        static let stream: Phase = (1.08, 1.88)   // travels up onto the island
        static let land:   Phase = (1.88, 2.18)   // impact — this point is the wave origin
        static let wave:   Phase = (2.18, 4.48)   // radiates, deforming over terrain
        static let recall: Phase = (4.48, 5.00)   // wave collapses back to the landing point
        static let ret:    Phase = (5.00, 5.80)   // streams back down the same path
        static let refill: Phase = (5.80, 6.45)   // settles into the bezel
        static let camIn:  Phase = (6.45, 7.45)   // map returns to the user's view
    }
    static let duration = 7.45
    /// Frost clears and the reveal callback fires here.
    static let revealAt = Phases.land.start

    // ── Look & feel ──────────────────────────────────────────────────────
    static let blobCount = 7
    static let gooBlur: CGFloat = 5        // pt. Must stay well under the gap between blobs.
    static let gooHalo = 0.22
    static let gooSheen = 0.22
    static let wavePoints = 220
    static let waveSlow = 0.20             // refraction — the front lags over high ground
    static let waveLift: CGFloat = 38      // pt the crest rides up the highest ground
    static let waveSmooth = 6              // ring samples averaged either side
    static let waveFlat = 0.94             // vertical squash — reads as a ground plane
    static let calm = 0.62                 // resting churn amplitude after a pulse

    static let islandCenter = (lng: 57.5450, lat: -20.1675)   // mercator centre — camera
    static let islandHeart = (lng: 57.5522, lat: -20.2833)    // central plateau — wave origin

    // ── Small maths ──────────────────────────────────────────────────────
    static func clamp01(_ v: Double) -> Double { min(1, max(0, v)) }
    static func norm(_ t: Double, _ p: Phase) -> Double { clamp01((t - p.start) / (p.end - p.start)) }
    static func easeOut(_ k: Double) -> Double { 1 - pow(1 - k, 3) }
    static func easeIO(_ k: Double) -> Double { k < 0.5 ? 4 * k * k * k : 1 - pow(-2 * k + 2, 3) / 2 }
    static func smooth(_ a: Double, _ b: Double, _ v: Double) -> Double {
        let k = clamp01((v - a) / (b - a)); return k * k * (3 - 2 * k)
    }
    static func mercY(_ lat: Double) -> Double { (1 - asinh(tan(lat * .pi / 180)) / .pi) / 2 }

    // ── Blobs ────────────────────────────────────────────────────────────
    struct Blob {
        let a0, r0, rad, spd, wob, lag: Double
    }
    /// orbit, radius, spin, wobble — spread so the discs part and re-merge instead of blurring into one lozenge.
    private static let blobSpec: [(Double, Double, Double, Double)] = [
        (9, 8, 0.31, 0.90), (16, 7, 0.24, 1.20), (21, 9, 0.38, 0.70), (19, 6, 0.28, 1.00),
        (13, 8, 0.44, 1.40), (20, 6, 0.35, 0.80), (15, 7, 0.21, 1.10),
    ]
    static let blobs: [Blob] = (0..<blobCount).map { i in
        let sp = blobSpec[i % blobSpec.count]
        return Blob(a0: Double(i) / Double(blobCount) * 2 * .pi + Double(i % 3) * 0.7,
                    r0: sp.0, rad: sp.1, spd: sp.2, wob: sp.3, lag: Double(i) / Double(blobCount) * 0.30)
    }

    /// Radius the liquid is confined to. 0 means unconfined.
    static func clipRadius(_ t: Double, inner: Double) -> Double {
        if t < Phases.escape.start { return inner }
        if t < Phases.escape.end { let k = norm(t, Phases.escape); return inner + k * k * 1200 }
        if t < Phases.refill.start { return 0 }
        if t < Phases.refill.end { let k = 1 - norm(t, Phases.refill); return inner + k * k * 1200 }
        return inner
    }

    /// One scalar description of where the liquid is at time t.
    struct Journey { let u, spread, scale, vis: Double }
    static func journey(_ t: Double) -> Journey {
        if t < Phases.gather.start { return Journey(u: 0, spread: 1, scale: 1, vis: 1) }
        if t < Phases.gather.end { let k = easeIO(norm(t, Phases.gather)); return Journey(u: 0, spread: 1 - k * 0.82, scale: 1 + k * 0.12, vis: 1) }
        if t < Phases.escape.end { let k = norm(t, Phases.escape); return Journey(u: easeOut(k) * 0.10, spread: 0.18, scale: 1.12 - k * 0.10, vis: 1) }
        if t < Phases.stream.end { let k = norm(t, Phases.stream); return Journey(u: 0.10 + easeIO(k) * 0.90, spread: 0.18 + k * 0.10, scale: 1.02 - k * 0.30, vis: 1) }
        if t < Phases.land.end { let k = norm(t, Phases.land); return Journey(u: 1, spread: 0.28 + k * 0.9, scale: 0.72 + k * 0.5, vis: 1 - easeOut(k)) }
        if t < Phases.wave.end { return Journey(u: 1, spread: 1.2, scale: 0.30, vis: 0) }
        if t < Phases.recall.end { let k = norm(t, Phases.recall); return Journey(u: 1, spread: 1.2 - k, scale: 0.30 + k * 0.50, vis: easeOut(k)) }
        if t < Phases.ret.end { let k = norm(t, Phases.ret); return Journey(u: 1 - easeIO(k), spread: 0.20, scale: 0.80 + k * 0.20, vis: 1) }
        if t < Phases.refill.end { let k = easeIO(norm(t, Phases.refill)); return Journey(u: 0, spread: 0.20 + k * 0.80, scale: 1, vis: 1) }
        return Journey(u: 0, spread: 1, scale: 1, vis: 1)
    }

    /// Quadratic path from the button (A) to the island heart (B) with a slight lateral bow.
    static func pathPoint(_ u: Double, _ a: CGPoint, _ b: CGPoint) -> CGPoint {
        let mx = (a.x + b.x) / 2 + (b.y - a.y) * 0.10
        let my = (a.y + b.y) / 2
        let v = 1 - u
        return CGPoint(x: v * v * a.x + 2 * v * u * mx + u * u * b.x,
                       y: v * v * a.y + 2 * v * u * my + u * u * b.y)
    }

    struct Disc { let center: CGPoint; let radius: CGFloat }
    static func blobsAt(_ t: Double, from a: CGPoint, to b: CGPoint, calm: Double) -> (discs: [Disc], vis: Double) {
        let j = journey(t)
        let discs = blobs.map { blob -> Disc in
            let bu = clamp01(j.u * (1 + blob.lag) - blob.lag)      // trailing droplets
            let p = pathPoint(bu, a, b)
            let ang = blob.a0 + t * blob.spd * 2 * .pi * 0.35
            let rr = blob.r0 * j.spread * calm * (1 + 0.28 * sin(t * blob.wob * 2 * .pi * 0.30 + blob.a0 * 3))
            return Disc(center: CGPoint(x: p.x + cos(ang) * rr, y: p.y + sin(ang) * rr * 0.82),
                        radius: max(1, blob.rad * j.scale))
        }
        return (discs, j.vis)
    }

    static func reliefAlpha(_ t: Double) -> Double {
        if t < Phases.land.start { return 0 }
        if t < Phases.wave.start { return norm(t, (Phases.land.start, Phases.wave.start)) * 0.55 }
        if t < Phases.recall.start { return 0.55 }
        if t < Phases.ret.start { return 0.55 * (1 - norm(t, (Phases.recall.start, Phases.ret.start))) }
        return 0
    }

    /// Radius of the wavefront at time t, in pt from the impact point. Near-linear on purpose.
    static func waveLead(_ t: Double, islandHeight: CGFloat, landReach: Double) -> CGFloat {
        pow(norm(t, Phases.wave), 0.9) * landReach * islandHeight
    }

    /// Trail/impact alpha helpers.
    static func trailAlpha(_ t: Double) -> Double {
        if t >= Phases.escape.start && t < Phases.land.end { return 0.5 * min(1, (t - Phases.escape.start) / 0.25) }
        if t >= Phases.recall.end && t < Phases.refill.start { return 0.5 }
        return 0
    }

    /// Frost: on from the start, clears across the impact.
    static func frostOpacity(_ t: Double) -> Double {
        if t < Phases.land.start { return 1 }
        if t < Phases.wave.start { return 1 - norm(t, (Phases.land.start, Phases.wave.start)) }
        return 0
    }

    /// Resting churn after a pulse: settles back toward full amplitude over a few seconds.
    static func calmAt(secondsSinceLastPulse: Double?) -> Double {
        guard let s = secondsSinceLastPulse else { return 1 }
        return calm + (1 - calm) * exp(-s / 2.5)
    }

    /// Zoom that frames the whole island in the given viewport (adaptive to any chrome height).
    static func fitZoom(viewport: CGSize, bbox: PulseFXTerrain.BBox) -> Double {
        let availW = max(80, viewport.width - 60), availH = max(80, viewport.height - 60)
        let world = min(availW / ((bbox.e - bbox.w) / 360), availH / (mercY(bbox.s) - mercY(bbox.n)))
        return max(8.1, min(9.6, log2(world / 512)))
    }
}
