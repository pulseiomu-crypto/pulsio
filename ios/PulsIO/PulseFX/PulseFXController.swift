import Foundation
import Observation
import UIKit

/// Runs a ceremony: owns the clock and every side effect — camera out/in, marker lighting as the wavefront
/// reaches each pin, reveal/done callbacks — through `MapSurface` only. Drawing is `PulseFXRenderer`'s job.
@MainActor
@Observable
final class PulseFXController {
    private(set) var isRunning = false
    /// Clock origin while running; the overlay derives `t` from it so the frame is a pure function of time.
    private(set) var startedAt: Date?
    private(set) var lastEndedAt: Date?
    let terrain: PulseFXTerrain?
    let renderer: PulseFXRenderer

    private weak var surface: (any MapSurface)?
    private var markers: [MapMarker] = []
    private var lit: Set<String> = []
    private var previousCamera: MapCamera?
    private var revealFired = false
    private var camInFired = false
    private var loop: Task<Void, Never>?
    private var viewport: CGSize = .zero

    init(terrain: PulseFXTerrain?) {
        self.terrain = terrain
        renderer = PulseFXRenderer(terrain: terrain)
    }

    func attach(_ surface: any MapSurface) { self.surface = surface }

    /// Elapsed seconds, clamped to the duration.
    func elapsed(at now: Date) -> Double {
        guard let startedAt else { return 0 }
        return min(PulseFXChoreography.duration, now.timeIntervalSince(startedAt))
    }

    /// Per-frame geometry for the renderer — the only place the map is consulted for drawing.
    func frame(button: CGPoint, buttonInner: CGFloat) -> PulseFXRenderer.Frame? {
        guard let surface else { return nil }
        let bb = PulseFXTerrain.bbox
        let tl = surface.project(latitude: bb.n, longitude: bb.w), br = surface.project(latitude: bb.s, longitude: bb.e)
        let heart = surface.project(latitude: PulseFXChoreography.islandHeart.lat, longitude: PulseFXChoreography.islandHeart.lng)
        return PulseFXRenderer.Frame(island: CGRect(x: tl.x, y: tl.y, width: br.x - tl.x, height: br.y - tl.y), heart: heart,
                                     button: button, buttonInner: buttonInner)
    }

    /// Reduced motion: no ceremony, no camera move — reveal immediately.
    func fire(markers: [MapMarker], viewport: CGSize, onReveal: @escaping @MainActor () -> Void, onDone: @escaping @MainActor () -> Void) {
        guard !isRunning, let surface else { onReveal(); onDone(); return }
        if UIAccessibility.isReduceMotionEnabled { onReveal(); onDone(); return }

        self.markers = markers
        self.viewport = viewport
        lit = []
        revealFired = false
        camInFired = false
        previousCamera = surface.camera
        surface.setInteractionEnabled(false)
        surface.setLitMarkers([])              // hidden until the wavefront reaches them
        let zoom = PulseFXChoreography.fitZoom(viewport: viewport, bbox: PulseFXTerrain.bbox)
        surface.setCamera(MapCamera(latitude: PulseFXChoreography.islandCenter.lat, longitude: PulseFXChoreography.islandCenter.lng, zoom: zoom),
                          duration: PulseFXChoreography.Phases.camOut.end - PulseFXChoreography.Phases.camOut.start)

        startedAt = .now
        isRunning = true
        loop = Task { [weak self] in
            while let self, self.isRunning, !Task.isCancelled {
                self.tick(onReveal: onReveal, onDone: onDone)
                try? await Task.sleep(for: .milliseconds(33))
            }
        }
    }

    func abort() {
        guard isRunning else { return }
        if !camInFired, let previousCamera { surface?.setCamera(previousCamera, duration: 0.4) }
        finish(onDone: nil)
    }

    private func tick(onReveal: @escaping @MainActor () -> Void, onDone: @escaping @MainActor () -> Void) {
        typealias C = PulseFXChoreography
        let t = elapsed(at: .now)
        if !revealFired, t >= C.revealAt { revealFired = true; onReveal() }
        if !camInFired, t >= C.Phases.camIn.start {
            camInFired = true
            if let previousCamera { surface?.setCamera(previousCamera, duration: C.Phases.camIn.end - C.Phases.camIn.start) }
        }
        if terrain != nil, t >= C.Phases.wave.start, t < C.Phases.recall.end { syncMarkers(t) }
        if t >= C.duration { finish(onDone: onDone) }
    }

    /// Light every marker the wavefront has reached. The camera is static during the wave, so projecting
    /// each tick is exact and cheap.
    private func syncMarkers(_ t: Double) {
        guard let surface, let terrain else { return }
        let bb = PulseFXTerrain.bbox
        let tl = surface.project(latitude: bb.n, longitude: bb.w), br = surface.project(latitude: bb.s, longitude: bb.e)
        let heart = surface.project(latitude: PulseFXChoreography.islandHeart.lat, longitude: PulseFXChoreography.islandHeart.lng)
        let lead = PulseFXChoreography.waveLead(t, islandHeight: br.y - tl.y, landReach: terrain.landReach)
        var changed = false
        for m in markers where !lit.contains(m.id) {
            let p = surface.project(latitude: m.latitude, longitude: m.longitude)
            let dx = p.x - heart.x, dy = (p.y - heart.y) / PulseFXChoreography.waveFlat
            if (dx * dx + dy * dy).squareRoot() <= lead { lit.insert(m.id); changed = true }
        }
        if changed { surface.setLitMarkers(lit) }
    }

    private func finish(onDone: (@MainActor () -> Void)?) {
        loop?.cancel()
        loop = nil
        isRunning = false
        startedAt = nil
        lastEndedAt = .now
        // Whatever happened, the map must never stay frozen or the pins hidden.
        surface?.setLitMarkers(nil)
        surface?.setInteractionEnabled(true)
        onDone?()
    }
}
