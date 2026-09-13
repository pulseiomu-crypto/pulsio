import CoreLocation
import MapLibre
import SwiftUI
import UIKit

/// The MapLibre Native adapter — the only file that imports MapLibre. Markers are a GeoJSON source drawn
/// by a data-driven circle layer (GPU-side, hundreds of pins are free), tinted by each marker's own colour.
@MainActor
final class MapLibreSurface: NSObject, MapSurface {
    let mapView: MLNMapView
    var onMarkerTap: ((MapMarker) -> Void)?

    private static let sourceID = "poi"
    private static let circleLayerID = "poi-circles"
    private static let haloLayerID = "poi-halo"
    private var markers: [String: MapMarker] = [:]
    private var pendingMarkers: [MapMarker]?
    private var features: [MLNPointFeature] = []
    private var litMarkers: Set<String>?

    init(initialCamera: MapCamera = .mauritius, basemap: Basemap = .default) {
        mapView = MLNMapView(frame: .zero, styleJSON: MapStyle.json(for: basemap))
        super.init()
        mapView.delegate = self
        mapView.minimumZoomLevel = 7.5
        mapView.maximumZoomLevel = 16          // ESRI's canvas stops here
        mapView.allowsRotating = false
        mapView.allowsTilting = false
        mapView.compassView.isHidden = true
        mapView.logoView.isHidden = true      // MapLibre logo is optional; tile/POI attribution is not (kept: ⓘ + strip)
        mapView.attributionButtonPosition = .bottomRight
        mapView.attributionButtonMargins = CGPoint(x: 8, y: 34)
        mapView.backgroundColor = UIColor(Palette.abyss)
        mapView.tintColor = UIColor(Palette.sky)   // the blue dot
        setCamera(initialCamera, animated: false)

        let tap = UITapGestureRecognizer(target: self, action: #selector(handleTap(_:)))
        for case let existing as UITapGestureRecognizer in mapView.gestureRecognizers ?? [] {
            tap.require(toFail: existing)      // keep MapLibre's double-tap zoom working
        }
        mapView.addGestureRecognizer(tap)
    }

    // MARK: MapSurface

    func project(latitude: Double, longitude: Double) -> CGPoint {
        mapView.convert(CLLocationCoordinate2D(latitude: latitude, longitude: longitude), toPointTo: mapView)
    }

    func unproject(_ point: CGPoint) -> (latitude: Double, longitude: Double) {
        let c = mapView.convert(point, toCoordinateFrom: mapView)
        return (c.latitude, c.longitude)
    }

    var camera: MapCamera {
        MapCamera(latitude: mapView.centerCoordinate.latitude, longitude: mapView.centerCoordinate.longitude,
                  zoom: mapView.zoomLevel, bearing: mapView.direction, pitch: Double(mapView.camera.pitch))
    }

    func setCamera(_ camera: MapCamera, animated: Bool) {
        mapView.setCenter(CLLocationCoordinate2D(latitude: camera.latitude, longitude: camera.longitude),
                          zoomLevel: camera.zoom, direction: camera.bearing, animated: animated)
    }

    func setMarkers(_ markers: [MapMarker]) {
        self.markers = Dictionary(uniqueKeysWithValues: markers.map { ($0.id, $0) })
        // `style` is nil until the style has loaded. With an inline JSON style that happens synchronously
        // in init — before the delegate is set — so the delegate callback alone can't be relied on.
        guard mapView.style != nil else {
            pendingMarkers = markers
            return
        }
        features = markers.map { marker -> MLNPointFeature in
            let f = MLNPointFeature()
            f.coordinate = CLLocationCoordinate2D(latitude: marker.latitude, longitude: marker.longitude)
            f.identifier = marker.id
            f.attributes = ["id": marker.id, "kind": marker.kind, "tint": marker.tintHex, "emphasis": marker.emphasis,
                            "title": marker.title, "lit": litMarkers?.contains(marker.id) ?? true]
            return f
        }
        pushFeatures()
    }

    func setLitMarkers(_ ids: Set<String>?) {
        litMarkers = ids
        for f in features {
            guard let id = f.attribute(forKey: "id") as? String else { continue }
            f.attributes["lit"] = ids?.contains(id) ?? true
        }
        pushFeatures()
    }

    private func pushFeatures() {
        guard let style = mapView.style else { return }
        if let source = style.source(withIdentifier: Self.sourceID) as? MLNShapeSource {
            source.shape = MLNShapeCollectionFeature(shapes: features)
        } else {
            let source = MLNShapeSource(identifier: Self.sourceID, features: features, options: nil)
            style.addSource(source)
            // Double ring (as NerveCentre): a dark halo layer beneath, a light stroke on the pin above, so pins
            // read on the dark canvas AND over turquoise lagoons and cane fields on imagery.
            style.addLayer(Self.makeHaloLayer(source: source))
            style.addLayer(Self.makeCircleLayer(source: source))
        }
    }

    func setCamera(_ camera: MapCamera, duration: TimeInterval) {
        let target = MLNMapCamera()
        target.centerCoordinate = CLLocationCoordinate2D(latitude: camera.latitude, longitude: camera.longitude)
        target.heading = camera.bearing
        target.pitch = camera.pitch
        target.altitude = MLNAltitudeForZoomLevel(camera.zoom, camera.pitch, camera.latitude, mapView.bounds.size)
        mapView.setCamera(target, withDuration: duration, animationTimingFunction: CAMediaTimingFunction(name: .easeInEaseOut))
    }

    func setInteractionEnabled(_ enabled: Bool) {
        mapView.isUserInteractionEnabled = enabled
    }

    func setShowsUserLocation(_ shows: Bool) {
        mapView.showsUserLocation = shows
    }

    /// Setting a new style drops every source and layer; the POI layers come back in `didFinishLoading`.
    func setBasemap(_ basemap: Basemap) {
        mapView.styleJSON = MapStyle.json(for: basemap)
    }

    // MARK: Styling

    /// Pin radius by zoom; emphasised markers (shelters) ~40% larger. `zoom` may only feed a top-level
    /// interpolate, so the halo gets its own stops (+2.5) rather than an arithmetic wrapper.
    private static func radius(plus extra: Double) -> [Any] {
        let e: [Any] = ["boolean", ["get", "emphasis"], false]
        return [
            "interpolate", ["linear"], ["zoom"],
            8, ["case", e, 4.5 + extra, 3.2 + extra],
            11, ["case", e, 7 + extra, 5 + extra],
            14, ["case", e, 11 + extra, 8 + extra],
        ]
    }

    /// The dark outer ring: a slightly larger abyss disc under each pin.
    private static func makeHaloLayer(source: MLNShapeSource) -> MLNCircleStyleLayer {
        let layer = MLNCircleStyleLayer(identifier: haloLayerID, source: source)
        layer.circleColor = NSExpression(forConstantValue: UIColor(Palette.abyss))
        layer.circleRadius = NSExpression(mglJSONObject: radius(plus: 2.5))
        layer.circleOpacity = NSExpression(mglJSONObject: ["case", ["boolean", ["get", "lit"], true], 0.9, 0])
        layer.circleStrokeWidth = NSExpression(forConstantValue: 0)
        return layer
    }

    private static func makeCircleLayer(source: MLNShapeSource) -> MLNCircleStyleLayer {
        let layer = MLNCircleStyleLayer(identifier: circleLayerID, source: source)
        // Style-spec expressions are statically typed: `get` yields an untyped value, so conditions must be
        // wrapped in `boolean` and colours in `to-color` or the whole property is rejected (silently).
        let emphasis: [Any] = ["boolean", ["get", "emphasis"], false]
        layer.circleColor = NSExpression(mglJSONObject: ["to-color", ["get", "tint"], Palette.Hex.string(Palette.Hex.muted)])
        // Grows with zoom; emphasised markers (shelters) ~40% larger.
        layer.circleRadius = NSExpression(mglJSONObject: radius(plus: 0))
        // The light inner ring — the second half of the double ring.
        layer.circleStrokeColor = NSExpression(forConstantValue: UIColor(Palette.bone))
        layer.circleStrokeWidth = NSExpression(mglJSONObject: ["case", emphasis, 2, 1.2])
        layer.circleOpacity = NSExpression(mglJSONObject: ["case", ["boolean", ["get", "lit"], true], 0.95, 0])
        layer.circleStrokeOpacity = NSExpression(mglJSONObject: ["case", ["boolean", ["get", "lit"], true], 1, 0])
        return layer
    }

    // MARK: Tap

    @objc private func handleTap(_ gesture: UITapGestureRecognizer) {
        let point = gesture.location(in: mapView)
        let hit = CGRect(x: point.x - 14, y: point.y - 14, width: 28, height: 28)   // ≥44pt effective target
        let features = mapView.visibleFeatures(in: hit, styleLayerIdentifiers: [Self.circleLayerID])
        guard let id = features.compactMap({ $0.attribute(forKey: "id") as? String }).first, let marker = markers[id] else { return }
        onMarkerTap?(marker)
    }
}

extension MapLibreSurface: @preconcurrency MLNMapViewDelegate {
    func mapView(_ mapView: MLNMapView, didFinishLoading style: MLNStyle) {
        if let pending = pendingMarkers {
            pendingMarkers = nil
            setMarkers(pending)
        } else if !features.isEmpty {
            pushFeatures()   // a basemap swap dropped the POI layers; put them back
        }
    }
}

/// SwiftUI host for a `MapLibreSurface`.
struct MapSurfaceView: UIViewRepresentable {
    let surface: MapLibreSurface

    func makeUIView(context: Context) -> MLNMapView { surface.mapView }
    func updateUIView(_ uiView: MLNMapView, context: Context) {}
}
