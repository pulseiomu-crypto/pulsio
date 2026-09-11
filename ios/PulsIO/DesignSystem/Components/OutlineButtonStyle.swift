import SwiftUI

/// The app's secondary button: mono label, hairline outline, press scale (RESTYLE Flag B — tactile).
/// `tint` colours both label and outline; the destructive variant uses coral.
struct OutlineButtonStyle: ButtonStyle {
    var tint: Color = Palette.teal
    var prominent = false

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(Typography.mono(11, weight: .semibold))
            .tracking(Typography.eyebrowTracking)
            .textCase(.uppercase)
            .foregroundStyle(prominent ? Palette.abyss : tint)
            .frame(maxWidth: .infinity, minHeight: 48)
            .padding(.horizontal, Metrics.Space.lg)
            .background(
                RoundedRectangle(cornerRadius: Metrics.Radius.sm, style: .continuous)
                    .fill(prominent ? tint : Color.clear)
            )
            .overlay(
                RoundedRectangle(cornerRadius: Metrics.Radius.sm, style: .continuous)
                    .stroke(tint.opacity(prominent ? 0 : 0.4), lineWidth: Metrics.hairline)
            )
            .scaleEffect(configuration.isPressed ? 0.97 : 1)
            .animation(Metrics.Motion.press, value: configuration.isPressed)
    }
}

extension ButtonStyle where Self == OutlineButtonStyle {
    static var outline: OutlineButtonStyle { OutlineButtonStyle() }
    static var prominent: OutlineButtonStyle { OutlineButtonStyle(prominent: true) }
    static var destructiveOutline: OutlineButtonStyle { OutlineButtonStyle(tint: Palette.coral) }
}
