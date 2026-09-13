import CoreLocation
import Foundation
import Observation

/// The device's location, and nothing more. Coordinates handed out here go to two places only: the map
/// (blue dot, drawn by the SDK itself) and `DistrictResolver` (on-device). They are never persisted or sent.
@MainActor
@Observable
final class LocationService: NSObject {
    enum Availability: Equatable {
        case notDetermined
        case denied
        case authorized
        case restricted
    }

    private(set) var availability: Availability
    private let manager = CLLocationManager()
    private var authorizationContinuation: CheckedContinuation<Availability, Never>?
    private var locationContinuation: CheckedContinuation<CLLocation, any Swift.Error>?

    override init() {
        availability = Self.map(manager.authorizationStatus)
        super.init()
        manager.delegate = self
        manager.desiredAccuracy = kCLLocationAccuracyHundredMeters   // district-grade is all we need
    }

    /// The system prompt. Ask only in context, after the in-app explanation (SPEC §10 flow).
    func requestWhenInUse() async -> Availability {
        guard availability == .notDetermined else { return availability }
        return await withCheckedContinuation { continuation in
            authorizationContinuation = continuation
            manager.requestWhenInUseAuthorization()
        }
    }

    /// One fix. Throws if unauthorised or the system can't produce a location.
    func currentLocation() async throws -> CLLocation {
        guard availability == .authorized else { throw Failure.notAuthorized }
        if let cached = manager.location, cached.timestamp.timeIntervalSinceNow > -60 { return cached }
        return try await withCheckedThrowingContinuation { continuation in
            locationContinuation = continuation
            manager.requestLocation()
        }
    }

    enum Failure: Swift.Error { case notAuthorized, unavailable }

    private static func map(_ status: CLAuthorizationStatus) -> Availability {
        switch status {
        case .notDetermined: .notDetermined
        case .restricted: .restricted
        case .denied: .denied
        case .authorizedAlways, .authorizedWhenInUse: .authorized
        @unknown default: .denied
        }
    }
}

extension LocationService: @preconcurrency CLLocationManagerDelegate {
    func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        availability = Self.map(manager.authorizationStatus)
        if availability != .notDetermined, let continuation = authorizationContinuation {
            authorizationContinuation = nil
            continuation.resume(returning: availability)
        }
    }

    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        guard let continuation = locationContinuation, let location = locations.last else { return }
        locationContinuation = nil
        continuation.resume(returning: location)
    }

    func locationManager(_ manager: CLLocationManager, didFailWithError error: any Swift.Error) {
        guard let continuation = locationContinuation else { return }
        locationContinuation = nil
        continuation.resume(throwing: Failure.unavailable)
    }
}
