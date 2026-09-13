import SwiftUI

/// Brand palette — the same values as the web `:root` tokens (RESTYLE-NOTES §1).
/// Teal is *reserved* for live/active; the other accents carry meaning (amber = warning/CEB, coral = alert,
/// sky = sea/humidity, green = safe/fuel, purple = politics). Neutral hairlines for structure.
enum Palette {
    /// The raw values — one source for SwiftUI `Color`s and for the map style, which wants `#RRGGBB` strings.
    enum Hex {
        static let abyss: UInt32 = 0x060E18
        static let deep: UInt32 = 0x081626
        static let bone: UInt32 = 0xE8F2EC
        static let teal: UInt32 = 0x00D4A8
        static let blue: UInt32 = 0x1B4FD8
        static let amber: UInt32 = 0xF5A623
        static let coral: UInt32 = 0xFF5A5A
        static let sky: UInt32 = 0x4AB8FF
        static let green: UInt32 = 0x3ED96E
        static let purple: UInt32 = 0xB09AFF
        static let transport: UInt32 = 0xFFFFFF   // infrastructure — airport, ferry, marina, flights (SPEC §24)
        static let muted: UInt32 = 0x93A39B   // opaque stand-in for bone@0.55 on abyss, for map use

        static func string(_ value: UInt32) -> String { String(format: "#%06X", value) }
    }

    // Brand
    static let abyss = Color(hex: Hex.abyss)   // page background
    static let deep = Color(hex: Hex.deep)     // surfaces
    static let bone = Color(hex: Hex.bone)     // ink
    static let teal = Color(hex: Hex.teal)
    static let blue = Color(hex: Hex.blue)

    // Semantic accents
    static let amber = Color(hex: Hex.amber)
    static let coral = Color(hex: Hex.coral)
    static let sky = Color(hex: Hex.sky)
    static let green = Color(hex: Hex.green)
    static let purple = Color(hex: Hex.purple)
    static let transport = Color(hex: Hex.transport)

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
