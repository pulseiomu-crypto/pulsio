import SwiftUI

/// The ceremony layer: sits above the map, below chrome. `TimelineView(.animation)` feeds the pure
/// `render(t)` each frame; frost is drawn here too (a visual, not a side effect).
struct PulseFXOverlay: View {
    let controller: PulseFXController
    /// Fire-button centre in this overlay's coordinate space, and the liquid's resting radius.
    let button: CGPoint
    let buttonInner: CGFloat

    var body: some View {
        if controller.isRunning {
            TimelineView(.animation) { timeline in
                let t = controller.elapsed(at: timeline.date)
                let frost = PulseFXChoreography.frostOpacity(t)
                ZStack {
                    if frost > 0.001 {
                        Rectangle().fill(.ultraThinMaterial).opacity(frost)
                    }
                    Canvas(rendersAsynchronously: false) { context, _ in
                        guard let frame = controller.frame(button: button, buttonInner: buttonInner) else { return }
                        controller.renderer.render(t, frame: frame, in: &context)
                    }
                }
            }
            .ignoresSafeArea()
            .allowsHitTesting(false)
            .transition(.opacity)
        }
    }
}
