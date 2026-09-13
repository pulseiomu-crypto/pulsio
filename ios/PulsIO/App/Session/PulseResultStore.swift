import CoreLocation
import Foundation
import Observation

/// The latest pulse's snapshot: server-assembled rows, plus the two things only the device can supply —
/// the nearest weather station and the sunset — and the priorities that reorder it.
@MainActor
@Observable
final class PulseResultStore {
    private(set) var rows: [PulsePanelRow] = []
    private(set) var takenAt: Date?
    private(set) var station: String?
    private(set) var isLoading = false
    private(set) var lastError: String?
    var isPresented = false

    private let panel: any PulsePanelRepository
    private let session: SessionStore
    private let districts: DistrictStore
    private let preferences: PreferencesStore
    private var stations: [WeatherStation] = []

    init(panel: any PulsePanelRepository, session: SessionStore, districts: DistrictStore, preferences: PreferencesStore) {
        self.panel = panel
        self.session = session
        self.districts = districts
        self.preferences = preferences
    }

    var hasResult: Bool { !rows.isEmpty }

    /// Fetch the snapshot for the current district / station / priorities and present it.
    func load(present: Bool = true) async {
        isLoading = true
        defer { isLoading = false }
        let reference = await districts.referenceCoordinate()
        let nearest = await nearestStation(to: reference)
        let priorities = preferences.priorities.map(\.rawValue)   // device copy; mirrors the profile once signed in
        do {
            var fetched = try await panel.snapshot(district: districts.district, station: nearest, priorities: priorities)
            fill(&fetched, sunsetAt: reference)
            rows = fetched
            station = nearest
            takenAt = .now
            lastError = nil
            if present { isPresented = true }
        } catch {
            lastError = String(describing: error)
        }
    }

    /// The `computed` rows the server orders but the device fills (SPEC §14: sunset from date + coordinates).
    private func fill(_ rows: inout [PulsePanelRow], sunsetAt reference: CLLocationCoordinate2D?) {
        let point = reference ?? CLLocationCoordinate2D(latitude: SunCalculator.islandCentre.latitude, longitude: SunCalculator.islandCentre.longitude)
        for i in rows.indices where rows[i].kind == .computed && rows[i].key == "sunset" {
            if let sunset = SunCalculator.sunset(on: .now, latitude: point.latitude, longitude: point.longitude, timeZone: SunCalculator.mauritius) {
                rows[i].value = .text(sunset.formatted(.dateTime.hour().minute().locale(Locale(identifier: "en_GB"))))
            }
        }
    }

    /// Nearest of the 10 stations to the reference point — picked here, on the device (SPEC §10/§14).
    private func nearestStation(to reference: CLLocationCoordinate2D?) async -> String? {
        guard let reference else { return nil }
        if stations.isEmpty { stations = (try? await panel.stations()) ?? [] }
        let from = CLLocation(latitude: reference.latitude, longitude: reference.longitude)
        return stations.min { a, b in
            CLLocation(latitude: a.lat, longitude: a.lng).distance(from: from) < CLLocation(latitude: b.lat, longitude: b.lng).distance(from: from)
        }?.station
    }
}
