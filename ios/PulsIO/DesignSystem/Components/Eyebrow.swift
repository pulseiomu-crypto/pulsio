import SwiftUI

/// Mono, uppercase, wide-tracked section label (the web `.eyebrow`).
struct Eyebrow: View {
    let text: LocalizedStringResource
    var tint: Color = Palette.muted

    var body: some View {
        Text(text)
            .font(Typography.mono(10, weight: .medium))
            .tracking(Typography.eyebrowTracking)
            .textCase(.uppercase)
            .foregroundStyle(tint)
    }
}
