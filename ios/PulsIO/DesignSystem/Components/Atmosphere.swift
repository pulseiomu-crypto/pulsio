import SwiftUI

/// The onboarding backdrop from the web app: radial teal/blue glows, 25 teal motes drifting upward, and a
/// faint CRT scanline. Particle paths derive from their index — no randomness, so every launch looks the same.
struct Atmosphere: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        ZStack {
            Palette.abyss
            RadialGradient(colors: [Palette.teal.opacity(0.07), .clear], center: UnitPoint(x: 0.5, y: 0.2), startRadius: 0, endRadius: 320)
            RadialGradient(colors: [Palette.blue.opacity(0.06), .clear], center: UnitPoint(x: 0.8, y: 0.8), startRadius: 0, endRadius: 260)
            RadialGradient(colors: [Palette.teal.opacity(0.04), .clear], center: UnitPoint(x: 0.15, y: 0.6), startRadius: 0, endRadius: 260)
            if !reduceMotion { ParticleField() }
            Scanlines()
        }
        .ignoresSafeArea()
        .accessibilityHidden(true)
    }
}

/// 25 motes, each on a 10–22 s loop: scale 0→1, fade in by 10 %, out by the top.
struct ParticleField: View {
    var body: some View {
        TimelineView(.animation) { timeline in
            let t = timeline.date.timeIntervalSinceReferenceDate
            Canvas { context, size in
                for i in 0..<25 {
                    // Deterministic per-index parameters (the web version used Math.random once at load).
                    let h = Double((i * 2654435761) & 0xFFFF) / 65535
                    let h2 = Double(((i + 7) * 40503) & 0xFFFF) / 65535
                    let duration = 10 + h * 12, delay = h2 * 15
                    let k = ((t + delay) / duration).truncatingRemainder(dividingBy: 1)
                    let opacity = k < 0.1 ? k / 0.1 * 0.4 : k < 0.9 ? 0.4 - (k - 0.1) / 0.8 * 0.25 : 0.15 * (1 - (k - 0.9) / 0.1)
                    let radius = (1 + h2 * 3) / 2 * k
                    let x = h * size.width, y = size.height + 10 - k * (size.height + 20)
                    context.fill(Path(ellipseIn: CGRect(x: x - radius, y: y - radius, width: radius * 2, height: radius * 2)),
                                 with: .color(Palette.teal.opacity(opacity)))
                }
            }
        }
    }
}

/// `repeating-linear-gradient(0deg, transparent 3px, rgba(0,0,0,.03) 4px)`.
struct Scanlines: View {
    var body: some View {
        Canvas { context, size in
            var y: CGFloat = 3
            while y < size.height {
                context.fill(Path(CGRect(x: 0, y: y, width: size.width, height: 1)), with: .color(.black.opacity(0.03)))
                y += 4
            }
        }
        .allowsHitTesting(false)
    }
}
