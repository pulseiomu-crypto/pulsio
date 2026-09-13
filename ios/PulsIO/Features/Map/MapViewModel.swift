import Foundation
import Observation

/// Map state: which optional layers are on, what's plotted, what's selected. Reads the device POI store
/// (never the network) and asks `POISync` to refresh it; talks to the map only through `MapSurface`.
@MainActor
@Observable
final class MapViewModel {
    private(set) var enabledLayers: Set<POIType> = []
    private(set) var basemap: Basemap
    private(set) var markers: [MapMarker] = []
    private(set) var selected: POIRecord?
    private(set) var loadError: String?

    private let store: POIStore
    private let sync: POISync
    private let session: SessionStore
    private weak var surface: (any MapSurface)?
    private var plotted: [String: POIRecord] = [:]
    private var emergencyActive = false

    private let defaults: UserDefaults

    init(store: POIStore, sync: POISync, session: SessionStore, defaults: UserDefaults = .standard) {
        self.store = store
        self.sync = sync
        self.session = session
        self.defaults = defaults
        basemap = defaults.string(forKey: Basemap.defaultsKey).flatMap(Basemap.init(rawValue:)) ?? .default
    }

    var syncPhase: POISync.Phase { sync.phase }

    func attach(_ surface: any MapSurface) {
        self.surface = surface
        surface.onMarkerTap = { [weak self] marker in self?.select(marker) }
        surface.setMarkers(markers)
    }

    /// Persisted between sessions.
    func setBasemap(_ basemap: Basemap) {
        guard basemap != self.basemap else { return }
        self.basemap = basemap
        defaults.set(basemap.rawValue, forKey: Basemap.defaultsKey)
        surface?.setBasemap(basemap)
    }

    /// Show whatever the device already has, then catch up with the server and show the result.
    func start() async {
        emergencyActive = session.emergency.isActive
        await reload()
        await sync.run()
        await reload()
    }

    /// Emergency-only categories (helipads) appear/disappear with the emergency flag (SPEC §20).
    func emergencyDidChange(_ active: Bool) async {
        guard active != emergencyActive else { return }
        emergencyActive = active
        await reload()
    }

    func showUserLocation(_ shows: Bool) {
        surface?.setShowsUserLocation(shows)
    }

    func centre(on latitude: Double, longitude: Double) {
        surface?.setCamera(MapCamera(latitude: latitude, longitude: longitude, zoom: 12), animated: true)
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
            let pois = try await store.plotted(enabledLayers: enabledLayers, emergencyActive: emergencyActive)
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
