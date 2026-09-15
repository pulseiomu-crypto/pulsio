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
    private(set) var selectedReportID: Int64?
    private(set) var loadError: String?
    private var reportMarkers: [MapMarker] = []
    /// A search hit that isn't normally plotted gets one transient pin while it's selected.
    private var searchMarker: MapMarker?
    static let searchMarkerPrefix = "search-"

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

    func dismissSelection() {
        selected = nil
        selectedReportID = nil
        if searchMarker != nil { searchMarker = nil; pushMarkers() }
    }

    /// A search result (SPEC §20): centre on it and open its card. Search-only types get a transient pin;
    /// approximate shelters get the card only — never a pin, never a camera move (nothing implies precision).
    func showSearchResult(_ poi: POIRecord) {
        searchMarker = nil
        if poi.type == .shelter && poi.locationPrecision == .approximate {
            selected = poi
            pushMarkers()
            return
        }
        if !plotted.keys.contains(String(poi.id)) {
            searchMarker = MapMarker(id: "\(Self.searchMarkerPrefix)\(poi.id)", latitude: poi.lat, longitude: poi.lng, kind: poi.type.rawValue,
                                     tintHex: poi.type.tintString, emphasis: true, title: poi.name)
        }
        selected = poi
        pushMarkers()
        surface?.setCamera(MapCamera(latitude: poi.lat, longitude: poi.lng, zoom: 14.5), animated: true)
    }

    private func pushMarkers() {
        surface?.setMarkers(markers + (searchMarker.map { [$0] } ?? []))
    }
    func dismissReport() { selectedReportID = nil }
    func openReport(id: Int64) { selected = nil; selectedReportID = id }

    /// Community reports ride on the same marker layer; the wavefront lights them like any other pin.
    func setReports(_ reports: [Report]) {
        reportMarkers = reports.map { r in
            MapMarker(id: r.markerID, latitude: r.lat, longitude: r.lng, kind: "report", tintHex: r.tintHex, emphasis: r.status == .confirmed, title: r.description ?? r.category.rawValue)
        }
        markers = markers.filter { !$0.id.hasPrefix(Report.markerPrefix) } + reportMarkers
        pushMarkers()
    }

    private func select(_ marker: MapMarker) {
        if marker.id.hasPrefix(Report.markerPrefix), let id = Int64(marker.id.dropFirst(Report.markerPrefix.count)) {
            selected = nil
            selectedReportID = id
        } else if marker.id.hasPrefix(Self.searchMarkerPrefix) {
            return   // already selected
        } else {
            selectedReportID = nil
            selected = plotted[marker.id]
        }
    }

    private func reload() async {
        do {
            let pois = try await store.plotted(enabledLayers: enabledLayers, emergencyActive: emergencyActive)
            plotted = Dictionary(uniqueKeysWithValues: pois.map { (String($0.id), $0) })
            markers = pois.map { poi in
                MapMarker(id: String(poi.id), latitude: poi.lat, longitude: poi.lng, kind: poi.type.rawValue,
                          tintHex: poi.type.tintString, emphasis: poi.type.isEmphasised, title: poi.name)
            } + reportMarkers
            loadError = nil
            pushMarkers()
        } catch {
            loadError = String(describing: error)
        }
    }
}
