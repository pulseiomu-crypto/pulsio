import CoreLocation
import Foundation
import Observation

/// The app's single location state (SPEC §10): a district and how it was set. GPS fills it automatically
/// when granted; the user picks it otherwise; both paths produce the same one field, and downstream can't
/// tell them apart. Persisted on the device always, and to the profile when signed in.
///
/// Privacy: the coordinate from `LocationService` is consumed by `DistrictResolver` right here and dropped.
/// Nothing in this type stores or transmits it.
@MainActor
@Observable
final class DistrictStore {
    enum Source: String, Sendable {
        case gps
        case manual
    }

    enum LocateOutcome: Equatable {
        case resolved(District)
        case unresolved          // authorised, but no fix or nothing nearby (off-island)
        case denied
    }

    private(set) var district: District?
    private(set) var source: Source?
    private(set) var lastError: String?

    private let defaults: UserDefaults
    private let location: LocationService
    private let resolver: DistrictResolver
    private let session: SessionStore
    private static let districtKey = "district"
    private static let sourceKey = "district.source"

    init(defaults: UserDefaults = .standard, location: LocationService, resolver: DistrictResolver, session: SessionStore) {
        self.defaults = defaults
        self.location = location
        self.resolver = resolver
        self.session = session
        district = defaults.string(forKey: Self.districtKey).flatMap(District.init(rawValue:))
        source = defaults.string(forKey: Self.sourceKey).flatMap(Source.init(rawValue:))
    }

    var locationAvailability: LocationService.Availability { location.availability }

    /// Manual choice (picker). Editable permanently, GPS-granted or not (SPEC §10 flow step 5).
    func setManual(_ district: District) async {
        await set(district, source: .manual)
    }

    /// Ask the system (only in context, after the in-app explanation), then resolve on-device.
    func locate() async -> LocateOutcome {
        let availability = await location.requestWhenInUse()
        guard availability == .authorized else { return .denied }
        do {
            let fix = try await location.currentLocation()
            guard let resolved = try await resolver.district(for: fix.coordinate) else { return .unresolved }
            await set(resolved, source: .gps)
            return .resolved(resolved)
        } catch {
            lastError = String(describing: error)
            return .unresolved
        }
    }

    /// Sign-in binds the device's district to the profile: the profile wins if it already has one,
    /// otherwise the device's choice is pushed up (FRONTEND §4: "sign-in later migrates them").
    func reconcile(with profile: Profile?) async {
        guard let profile else { return }
        if let remote = profile.district {
            if remote != district { persist(remote, source: source ?? .manual) }
        } else if let local = district {
            do { try await session.updateDistrict(local) } catch { lastError = String(describing: error) }
        }
    }

    private func set(_ district: District, source: Source) async {
        persist(district, source: source)
        if session.isSignedIn {
            do { try await session.updateDistrict(district) } catch { lastError = String(describing: error) }
        }
    }

    private func persist(_ district: District, source: Source) {
        self.district = district
        self.source = source
        defaults.set(district.rawValue, forKey: Self.districtKey)
        defaults.set(source.rawValue, forKey: Self.sourceKey)
    }
}
