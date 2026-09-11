import SwiftUI
import UIKit

/// Type ramp. The web app pairs Syne (display) / IBM Plex Mono (labels, data) / Instrument Sans (body).
/// The brand faces aren't bundled yet, so each role maps to a system design with the same *job*;
/// swapping in the real fonts is a change here only.
///
/// Every size scales with Dynamic Type (SPEC §8): the point size given is the size at the default
/// content size, scaled through the nearest text style's metrics.
enum Typography {
    /// Display — headings, headline in detail. Syne 700.
    static func display(_ size: CGFloat, weight: Font.Weight = .bold) -> Font {
        .system(size: scaled(size, .title2), weight: weight, design: .default)
    }

    /// Body — running text, list headlines. Instrument Sans 400/500.
    static func body(_ size: CGFloat = 13, weight: Font.Weight = .regular) -> Font {
        .system(size: scaled(size, .body), weight: weight, design: .default)
    }

    /// Mono — eyebrows, meta lines, data. IBM Plex Mono 400–600.
    static func mono(_ size: CGFloat = 10, weight: Font.Weight = .medium) -> Font {
        .system(size: scaled(size, .caption1), weight: weight, design: .monospaced)
    }

    /// Eyebrow tracking, pushed wide per RESTYLE-NOTES ✅4 (.2–.28em).
    static let eyebrowTracking: CGFloat = 0.22

    private static func scaled(_ size: CGFloat, _ style: UIFont.TextStyle) -> CGFloat {
        UIFontMetrics(forTextStyle: style).scaledValue(for: size)
    }
}
