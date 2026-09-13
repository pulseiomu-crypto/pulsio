import SwiftUI

/// Where the panel lives (SPEC §7): iPhone — a bottom sheet with peek/half/full detents so the island stays
/// visible after the reveal; iPad/desktop — the single right-hand panel slot (filters are restored on close).
struct PulsePanelHost<Content: View>: View {
    @Environment(PulseResultStore.self) private var result
    @Environment(\.horizontalSizeClass) private var sizeClass
    let content: () -> Content
    var onTap: ((PulsePanelRow) -> Void)? = nil
    @State private var detent: PresentationDetent = .medium

    var body: some View {
        @Bindable var result = result
        if sizeClass == .regular {
            HStack(spacing: 0) {
                content()
                if result.isPresented {
                    PulsePanelView(onTap: onTap)
                        .overlay(alignment: .topTrailing) {
                            Button { result.isPresented = false } label: {
                                Image(systemName: "xmark").font(.system(size: 12, weight: .semibold)).foregroundStyle(Palette.muted)
                                    .frame(width: 44, height: 44)
                            }
                            .buttonStyle(.plain)
                            .accessibilityLabel(Text("common.close"))
                        }
                        .frame(width: 380)
                        .overlay(alignment: .leading) { Rectangle().fill(Palette.hairStrong).frame(width: Metrics.hairline) }
                        .transition(.move(edge: .trailing))
                }
            }
            .animation(Metrics.Motion.entrance, value: result.isPresented)
        } else {
            content()
                .sheet(isPresented: $result.isPresented, onDismiss: { detent = .medium }) {
                    PulsePanelView(onTap: onTap)
                        .presentationDetents([.height(132), .medium, .large], selection: $detent)
                        .presentationDragIndicator(.visible)
                        .presentationBackgroundInteraction(.enabled(upThrough: .medium))
                        .presentationBackground(Palette.abyss)
                }
        }
    }
}
