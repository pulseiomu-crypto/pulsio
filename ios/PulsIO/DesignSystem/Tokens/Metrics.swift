import SwiftUI

/// Spacing, radii, hairlines, motion — RESTYLE-NOTES §3–§5 and the ✅ applied changes.
enum Metrics {
    /// 4pt scale (Tailwind rhythm the app already uses).
    enum Space {
        static let xs: CGFloat = 4
        static let sm: CGFloat = 8
        static let md: CGFloat = 12
        static let lg: CGFloat = 16
        static let xl: CGFloat = 24
    }

    /// Radii, moved up the ramp toward the landing's 14–22 (RESTYLE ✅2).
    enum Radius {
        static let xs: CGFloat = 8
        static let sm: CGFloat = 12
        static let md: CGFloat = 16
        static let lg: CGFloat = 20
        static let xl: CGFloat = 22
    }

    /// Structural hairline — 0.5pt, not 1 (RESTYLE ✅1).
    static let hairline: CGFloat = 0.5

    enum Motion {
        static let fast: Double = 0.14
        static let base: Double = 0.24
        static let slow: Double = 0.42
        /// Long ease-out for entrances (RESTYLE ✅5): cubic-bezier(.2,.7,.2,1).
        static let entrance = Animation.timingCurve(0.2, 0.7, 0.2, 1, duration: 0.6)
        static let press = Animation.spring(response: 0.24, dampingFraction: 0.7)
    }
}
