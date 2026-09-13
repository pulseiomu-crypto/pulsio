import SwiftUI

/// Draws one frame of the ceremony. Pure: given `t` and the frame geometry (which the host derives from
/// `MapSurface.project` — the entire map dependency), it paints into the context and returns the wavefront.
/// It knows nothing about the map SDK, Supabase, or any feature.
struct PulseFXRenderer {
    /// Everything that depends on the camera, resolved by the host per frame.
    struct Frame {
        /// The heightmap's on-screen rect (two projected bbox corners).
        let island: CGRect
        /// Projected island heart — impact point and wave origin.
        let heart: CGPoint
        /// Fire button centre and the radius the liquid is confined to at rest.
        let button: CGPoint
        let buttonInner: CGFloat
    }

    let terrain: PulseFXTerrain?

    private static let teal = Color(red: 0, green: 212 / 255, blue: 168 / 255)
    private static let core = Color(red: 90 / 255, green: 245 / 255, blue: 210 / 255)
    private static let crest = Color(red: 150 / 255, green: 1, blue: 230 / 255)
    private static let flash = Color(red: 190 / 255, green: 1, blue: 240 / 255)

    /// Returns the wavefront radius (pt) so the host can light markers the front has reached.
    @discardableResult
    func render(_ t: Double, frame: Frame, in context: inout GraphicsContext) -> CGFloat {
        typealias C = PulseFXChoreography
        let lead = C.waveLead(t, islandHeight: frame.island.height, landReach: terrain?.landReach ?? 1)
        drawRelief(t, frame: frame, in: &context)
        drawWave(t, frame: frame, lead: lead, in: &context)
        drawImpact(t, at: frame.heart, in: &context)
        drawTrail(t, from: frame.button, to: frame.heart, in: &context)
        let s = C.blobsAt(t, from: frame.button, to: frame.heart, calm: 1)
        if s.vis > 0.001 {
            let clipR = C.clipRadius(t, inner: Double(frame.buttonInner))
            drawGoo(s.discs, alpha: s.vis, clip: clipR > 0 ? (frame.button, CGFloat(clipR)) : nil, in: &context)
        }
        return lead
    }

    /// The idle churn inside the fire button (no journey, confined to the bezel).
    func renderIdle(_ t: Double, center: CGPoint, inner: CGFloat, calm: Double, in context: inout GraphicsContext) {
        let s = PulseFXChoreography.blobsAt(t, from: center, to: center, calm: calm)
        drawGoo(s.discs, alpha: 1, clip: (center, inner), in: &context)
    }

    // MARK: Layers

    private func drawRelief(_ t: Double, frame: Frame, in context: inout GraphicsContext) {
        guard let terrain else { return }
        let a = PulseFXChoreography.reliefAlpha(t)
        guard a > 0.001 else { return }
        context.drawLayer { layer in
            layer.blendMode = .plusLighter
            layer.opacity = a
            layer.draw(Image(decorative: terrain.relief, scale: 1), in: frame.island)
        }
    }

    /// A ring of points displaced by the terrain beneath: slower over high ground (refraction), lifted at the
    /// crest. Vertex displacement, then feathered to the island silhouette with the baked mask.
    private func drawWave(_ t: Double, frame: Frame, lead: CGFloat, in context: inout GraphicsContext) {
        typealias C = PulseFXChoreography
        guard let terrain else { return }
        let k = C.norm(t, C.Phases.wave)
        guard k > 0, k < 1 else { return }
        let env = min(1, k * 6) * min(1, (1 - k) * 4)
        let n = C.wavePoints
        var hs = [Double](repeating: 0, count: n), hsm = [Double](repeating: 0, count: n)

        context.drawLayer { layer in
            layer.blendMode = .plusLighter
            layer.clipToLayer { mask in mask.draw(Image(decorative: terrain.mask, scale: 1), in: frame.island) }
            for ring in 0..<3 {
                let rr = lead - CGFloat(ring) * 16
                guard rr > 4 else { continue }
                let a = env * (ring == 0 ? 0.95 : ring == 1 ? 0.45 : 0.20)
                for i in 0..<n {
                    let th = Double(i) / Double(n) * 2 * .pi
                    hs[i] = terrain.sampleHeight(at: CGPoint(x: frame.heart.x + CGFloat(cos(th)) * rr,
                                                             y: frame.heart.y + CGFloat(sin(th)) * rr * C.waveFlat), in: frame.island)
                }
                // Smooth along the ring: terrain noise becomes the broad bulge of a wave climbing a mountain.
                for i in 0..<n {
                    var acc = 0.0
                    for j in -C.waveSmooth...C.waveSmooth { acc += hs[(i + j + n) % n] }
                    hsm[i] = acc / Double(C.waveSmooth * 2 + 1)
                }
                var path = Path()
                for i in 0...n {
                    let th = Double(i) / Double(n) * 2 * .pi
                    let h = hsm[i % n]
                    let r2 = rr * (1 - h * C.waveSlow)
                    let p = CGPoint(x: frame.heart.x + CGFloat(cos(th)) * r2,
                                    y: frame.heart.y + CGFloat(sin(th)) * r2 * C.waveFlat - h * C.waveLift)
                    if i == 0 { path.move(to: p) } else { path.addLine(to: p) }
                }
                path.closeSubpath()
                if ring == 0 {
                    layer.stroke(path, with: .color(Self.teal.opacity(a * 0.26)), style: StrokeStyle(lineWidth: 14, lineJoin: .round))
                    layer.stroke(path, with: .color(Self.crest.opacity(a)), style: StrokeStyle(lineWidth: 3.5, lineJoin: .round))
                } else {
                    layer.stroke(path, with: .color(Self.teal.opacity(a)), style: StrokeStyle(lineWidth: 2, lineJoin: .round))
                }
            }
        }
    }

    private func drawImpact(_ t: Double, at b: CGPoint, in context: inout GraphicsContext) {
        typealias C = PulseFXChoreography
        let end = C.Phases.land.end + 0.4
        guard t >= C.Phases.land.start, t <= end else { return }
        let k = C.clamp01((t - C.Phases.land.start) / (end - C.Phases.land.start))
        let r = 8 + C.easeOut(k) * 90, a = (1 - k) * 0.75
        context.drawLayer { layer in
            layer.blendMode = .plusLighter
            let rect = CGRect(x: b.x - r, y: b.y - r, width: r * 2, height: r * 2)
            layer.fill(Path(ellipseIn: rect), with: .radialGradient(
                Gradient(stops: [.init(color: Self.flash.opacity(a * 0.90), location: 0),
                                 .init(color: Self.teal.opacity(a * 0.35), location: 0.55),
                                 .init(color: Self.teal.opacity(0), location: 1)]),
                center: b, startRadius: 0, endRadius: r))
        }
    }

    private func drawTrail(_ t: Double, from a: CGPoint, to b: CGPoint, in context: inout GraphicsContext) {
        let alpha = PulseFXChoreography.trailAlpha(t)
        guard alpha > 0.001 else { return }
        var path = Path()
        for i in 0...24 {
            let p = PulseFXChoreography.pathPoint(Double(i) / 24, a, b)
            if i == 0 { path.move(to: p) } else { path.addLine(to: p) }
        }
        context.drawLayer { layer in
            layer.blendMode = .plusLighter
            layer.stroke(path, with: .linearGradient(
                Gradient(stops: [.init(color: Self.teal.opacity(0), location: 0),
                                 .init(color: Self.teal.opacity(alpha * 0.30), location: 0.5),
                                 .init(color: Self.teal.opacity(0), location: 1)]),
                startPoint: a, endPoint: b), style: StrokeStyle(lineWidth: 3, lineCap: .round))
        }
    }

    /// Gooey metaballs: the blurred coverage of all discs, thresholded to a hard teal body (`alphaThreshold`),
    /// with the un-thresholded blur kept faintly as a halo and one top-lit sheen across the whole silhouette.
    /// Filters apply to the layer's composite in reverse order of addition (threshold ∘ blur).
    private func drawGoo(_ discs: [PulseFXChoreography.Disc], alpha: Double, clip: (center: CGPoint, radius: CGFloat)?, in context: inout GraphicsContext) {
        guard alpha > 0.001 else { return }
        let blur = PulseFXChoreography.gooBlur
        var bounds = discs.reduce(CGRect.null) { $0.union(CGRect(x: $1.center.x - $1.radius, y: $1.center.y - $1.radius, width: $1.radius * 2, height: $1.radius * 2)) }
        bounds = bounds.insetBy(dx: -blur * 3, dy: -blur * 3)
        func drawDiscs(_ c: inout GraphicsContext, color: Color) {
            for d in discs {
                c.fill(Path(ellipseIn: CGRect(x: d.center.x - d.radius, y: d.center.y - d.radius, width: d.radius * 2, height: d.radius * 2)), with: .color(color))
            }
        }
        context.drawLayer { outer in
            if let clip {
                outer.clip(to: Path(ellipseIn: CGRect(x: clip.center.x - clip.radius, y: clip.center.y - clip.radius, width: clip.radius * 2, height: clip.radius * 2)))
            }
            outer.opacity = alpha
            // Halo: the soft field outside the hard edge.
            outer.drawLayer { halo in
                halo.opacity = PulseFXChoreography.gooHalo
                halo.addFilter(.blur(radius: blur))
                halo.drawLayer { inner in drawDiscs(&inner, color: Self.teal) }
            }
            // Body: flat brand teal, exactly.
            outer.drawLayer { body in
                body.addFilter(.alphaThreshold(min: 0.5, color: Self.teal))
                body.addFilter(.blur(radius: blur))
                body.drawLayer { inner in drawDiscs(&inner, color: .white) }
            }
            // Sheen: one top-lit gradient confined to the body.
            outer.drawLayer { sheen in
                sheen.clipToLayer { m in
                    m.addFilter(.alphaThreshold(min: 0.5, color: .white))
                    m.addFilter(.blur(radius: blur))
                    m.drawLayer { inner in drawDiscs(&inner, color: .white) }
                }
                sheen.fill(Path(bounds), with: .linearGradient(
                    Gradient(stops: [.init(color: Self.core.opacity(PulseFXChoreography.gooSheen), location: 0),
                                     .init(color: Self.core.opacity(0), location: 0.55)]),
                    startPoint: CGPoint(x: bounds.midX, y: bounds.minY), endPoint: CGPoint(x: bounds.midX, y: bounds.maxY)))
            }
        }
    }
}
