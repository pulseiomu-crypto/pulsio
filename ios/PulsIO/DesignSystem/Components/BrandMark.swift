import SwiftUI

/// The logo: three breathing rings, a blue core, and a slow orbit of three teal dots — ported from the
/// landing/onboarding SVG. Deterministic and time-driven; still under Reduce Motion.
struct BrandMark: View {
    var size: CGFloat = 112
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        TimelineView(.animation(paused: reduceMotion)) { timeline in
            let t = reduceMotion ? 0 : timeline.date.timeIntervalSinceReferenceDate
            Canvas { context, canvasSize in
                let c = CGPoint(x: canvasSize.width / 2, y: canvasSize.height / 2)
                let u = canvasSize.width / 200   // the SVG's 200-unit box
                // Rings breathe over 4 s, staggered by 1 s: opacity .3 → .12, scale 1 → 1.08.
                for (i, r) in [90.0, 70.0, 50.0].enumerated() {
                    let phase = (t - Double(i)) / 4
                    let k = 0.5 - 0.5 * cos(phase * 2 * .pi)          // 0…1…0
                    let opacity = 0.3 - 0.18 * k, scale = 1 + 0.08 * k
                    let rr = r * u * scale
                    context.stroke(Path(ellipseIn: CGRect(x: c.x - rr, y: c.y - rr, width: rr * 2, height: rr * 2)),
                                   with: .color(Palette.teal.opacity(opacity)), lineWidth: 1.5 * u)
                }
                context.fill(Path(ellipseIn: CGRect(x: c.x - 30 * u, y: c.y - 30 * u, width: 60 * u, height: 60 * u)), with: .color(Palette.blue))
                context.fill(Path(ellipseIn: CGRect(x: c.x - 18 * u, y: c.y - 18 * u, width: 36 * u, height: 36 * u)), with: .color(Color(hex: 0x2563EB)))
                context.fill(Path(ellipseIn: CGRect(x: c.x - 5 * u, y: c.y - 5 * u, width: 10 * u, height: 10 * u)), with: .color(.white))
                // Orbit: 10 s per revolution.
                let rot = (t / 10).truncatingRemainder(dividingBy: 1) * 2 * .pi
                for (angle, radius, dot) in [(-Double.pi / 2, 50.0, 3.0), (0.0, 70.0, 2.5), (Double.pi / 2, 70.0, 2.0)] {
                    let a = angle + rot
                    let p = CGPoint(x: c.x + cos(a) * radius * u, y: c.y + sin(a) * radius * u)
                    context.fill(Path(ellipseIn: CGRect(x: p.x - dot * u, y: p.y - dot * u, width: dot * 2 * u, height: dot * 2 * u)), with: .color(Palette.teal))
                }
            }
        }
        .frame(width: size, height: size)
        .accessibilityHidden(true)
    }
}

/// "PulsIO" — bone + teal, tight tracking.
struct Wordmark: View {
    var size: CGFloat = 36

    var body: some View {
        HStack(spacing: 0) {
            Text(verbatim: "Puls").foregroundStyle(Palette.ink)
            Text(verbatim: "IO").foregroundStyle(Palette.teal)
        }
        .font(Typography.display(size, weight: .heavy))
        .tracking(-size * 0.04)
        .accessibilityLabel(Text(verbatim: "PulsIO"))
    }
}
