import SwiftUI

/// Brand palette — the same values as the web `:root` tokens (RESTYLE-NOTES §1).
/// Teal is *reserved* for live/active; the other accents carry meaning (amber = warning/CEB, coral = alert,
/// sky = sea/humidity, green = safe/fuel, purple = politics). Neutral hairlines for structure.
enum Palette {
    // Brand
    static let abyss = Color(hex: 0x060E18)   // page background
    static let deep = Color(hex: 0x081626)    // surfaces
    static let bone = Color(hex: 0xE8F2EC)    // ink
    static let teal = Color(hex: 0x00D4A8)
    static let blue = Color(hex: 0x1B4FD8)

    // Semantic accents
    static let amber = Color(hex: 0xF5A623)
    static let coral = Color(hex: 0xFF5A5A)
    static let sky = Color(hex: 0x4AB8FF)
    static let green = Color(hex: 0x3ED96E)
    static let purple = Color(hex: 0xB09AFF)

    // Text
    static let ink = bone
    static let muted = bone.opacity(0.55)     // brighter than the landing page on purpose — legibility outdoors
    static let muted2 = bone.opacity(0.34)

    // Hairlines — neutral for structure, teal only for active
    static let hair = bone.opacity(0.09)
    static let hairStrong = bone.opacity(0.15)
    static let hairActive = teal.opacity(0.40)

    // Surface stack
    static let surface1 = Color(hex: 0x0D1E30).opacity(0.78)
    static let surface2Top = Color(hex: 0x0C1C2E)
    static let surface2Bottom = Color(hex: 0x081524)
}

extension Color {
    init(hex: UInt32, opacity: Double = 1) {
        self.init(
            .sRGB,
            red: Double((hex >> 16) & 0xFF) / 255,
            green: Double((hex >> 8) & 0xFF) / 255,
            blue: Double(hex & 0xFF) / 255,
            opacity: opacity
        )
    }
}
