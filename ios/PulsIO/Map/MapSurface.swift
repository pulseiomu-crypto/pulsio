import CoreLocation
import Foundation

/// A camera position, SDK-neutral.
struct MapCamera: Equatable, Sendable {
    var latitude: Double
    var longitude: Double
    var zoom: Double
    var bearing: Double = 0
    var pitch: Double = 0

    /// Mauritius, main island, framed like the web app (FRONTEND §B).
    static let mauritius = MapCamera(latitude: -20.25, longitude: 57.55, zoom: 9.2)
}

/// One thing drawn on the map. Colour is meaning (SPEC semantic palette), so the tint travels with the marker.
struct MapMarker: Identifiable, Equatable, Sendable {
    let id: String
    let latitude: Double
    let longitude: Double
    /// Free-form kind for styling/filtering (a `POIType` raw value today).
    let kind: String
    /// `#RRGGBB`
    let tintHex: String
    /// Drawn larger with a light stroke — shelters, so they read at a glance during a cyclone.
    let emphasis: Bool
    let title: String
}

/// The contract every map-dependent piece codes against (ARCHITECTURE §4/§5): features, and later PulseFX,
/// see only `project`/`unproject`, the camera and markers — never the SDK. Web implements the same shape
/// over MapLibre GL JS, which is what keeps the pulse animation portable.
@MainActor
protocol MapSurface: AnyObject {
    func project(latitude: Double, longitude: Double) -> CGPoint
    func unproject(_ point: CGPoint) -> (latitude: Double, longitude: Double)

    var camera: MapCamera { get }
    func setCamera(_ camera: MapCamera, animated: Bool)

    func setMarkers(_ markers: [MapMarker])
    var onMarkerTap: ((MapMarker) -> Void)? { get set }
}
