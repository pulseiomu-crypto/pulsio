import SwiftUI

/// A pill you toggle: symbol + mono label; teal fill/outline when on (the web `.chip.on`).
struct SelectableChip: View {
    let title: LocalizedStringResource
    let symbol: String
    let isOn: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: Metrics.Space.sm) {
                Image(systemName: symbol).font(.system(size: 12, weight: .semibold))
                Text(title)
            }
            .font(Typography.mono(12, weight: .medium))
            .foregroundStyle(isOn ? Palette.teal : Palette.muted)
            .padding(.horizontal, Metrics.Space.lg)
            .frame(minHeight: 44)
            .background(isOn ? Palette.teal.opacity(0.18) : Palette.teal.opacity(0.08), in: Capsule())
            .overlay(Capsule().stroke(isOn ? Palette.hairActive : Palette.hair, lineWidth: isOn ? 1 : Metrics.hairline))
            .shadow(color: Palette.teal.opacity(isOn ? 0.25 : 0), radius: 12, y: 6)
            .animation(Metrics.Motion.press, value: isOn)
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(isOn ? .isSelected : [])
    }
}
