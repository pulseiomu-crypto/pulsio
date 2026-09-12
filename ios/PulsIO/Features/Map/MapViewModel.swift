import Foundation
import Observation

/// Map state: which optional layers are on, what's plotted, what's selected. Reads the device POI store
/// (never the network) and asks `POISync` to refresh it; talks to the map only through `MapSurface`.
@MainActor
@Observable
final class MapViewModel {
    private(set) var enabledLayers: Set<POIType> = []
    private(set) var markers: [MapMarker] = []
    private(set) var selected: POIRecord?
    private(set) var loadError: String?

    private let store: POIStore
    private let sync: POISync
    private weak var surface: (any MapSurface)?
    private var plotted: [String: POIRecord] = [:]

    init(store: POIStore, sync: POISync) {
        self.store = store
        self.sync = sync
    }

    var syncPhase: POISync.Phase { sync.phase }

    func attach(_ surface: any MapSurface) {
        self.surface = surface
        surface.onMarkerTap = { [weak self] marker in self?.select(marker) }
        surface.setMarkers(markers)
    }

    /// Show whatever the device already has, then catch up with the server and show the result.
    func start() async {
        await reload()
        await sync.run()
        await reload()
    }

    func refresh() async {
        await sync.run()
        await reload()
    }

    func isEnabled(_ layer: POIType) -> Bool { enabledLayers.contains(layer) }

    func toggle(_ layer: POIType) async {
        if enabledLayers.contains(layer) { enabledLayers.remove(layer) } else { enabledLayers.insert(layer) }
        await reload()
    }

    func dismissSelection() { selected = nil }

    private func select(_ marker: MapMarker) {
        selected = plotted[marker.id]
    }

    private func reload() async {
        do {
            let pois = try await store.plotted(enabledLayers: enabledLayers)
            plotted = Dictionary(uniqueKeysWithValues: pois.map { (String($0.id), $0) })
            markers = pois.map { poi in
                MapMarker(id: String(poi.id), latitude: poi.lat, longitude: poi.lng, kind: poi.type.rawValue,
                          tintHex: poi.type.tintString, emphasis: poi.type.isEmphasised, title: poi.name)
            }
            loadError = nil
            surface?.setMarkers(markers)
        } catch {
            loadError = String(describing: error)
        }
    }
}
