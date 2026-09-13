import Foundation

/// Basemaps as MapLibre style documents — the same three keyless ESRI layers NerveCentre uses.
/// Attribution strings feed MapLibre's ⓘ button; the always-visible strip lives in the Map feature.
enum Basemap: String, CaseIterable, Codable, Sendable, Identifiable {
    case dark, satellite, street
    var id: String { rawValue }
    static let `default` = Basemap.dark
    static let defaultsKey = "map.basemap"

    var label: LocalizedStringResource {
        switch self {
        case .dark: "map.basemap.dark"
        case .satellite: "map.basemap.satellite"
        case .street: "map.basemap.street"
        }
    }

    var symbol: String {
        switch self {
        case .dark: "circle.lefthalf.filled"
        case .satellite: "globe.europe.africa.fill"
        case .street: "map"
        }
    }

    /// Bright imagery/streets need the markers' dark outer ring to do the separating; on dark it's invisible.
    var isBright: Bool { self != .dark }
}

enum MapStyle {
    static let backgroundHex = "#060E18"   // Palette.abyss

    private static let esri = "https://server.arcgisonline.com/ArcGIS/rest/services"
    private static func tiles(_ service: String) -> String { "\(esri)/\(service)/MapServer/tile/{z}/{y}/{x}" }

    static let darkAttribution = "Basemap © Esri, HERE, Garmin, FAO, NOAA, USGS, © OpenStreetMap contributors"
    static let satelliteAttribution = "Imagery © Esri, Maxar, Earthstar Geographics, and the GIS User Community"
    static let streetAttribution = "Basemap © Esri, HERE, Garmin, © OpenStreetMap contributors, and the GIS User Community"

    static func json(for basemap: Basemap) -> String {
        let sources: [String: Any]
        let layers: [[String: Any]]
        switch basemap {
        case .dark:
            sources = [
                "base": ["type": "raster", "tiles": [tiles("Canvas/World_Dark_Gray_Base")], "tileSize": 256, "maxzoom": 16, "attribution": darkAttribution],
                "reference": ["type": "raster", "tiles": [tiles("Canvas/World_Dark_Gray_Reference")], "tileSize": 256, "maxzoom": 16],
            ]
            layers = [
                ["id": "background", "type": "background", "paint": ["background-color": backgroundHex]],
                // Pulled toward the app's abyss so semantic pins stay the loudest thing.
                ["id": "base", "type": "raster", "source": "base", "paint": ["raster-brightness-max": 0.72, "raster-saturation": -0.2, "raster-contrast": 0.05]],
                ["id": "reference", "type": "raster", "source": "reference", "paint": ["raster-opacity": 0.85]],
            ]
        case .satellite:
            sources = [
                "base": ["type": "raster", "tiles": [tiles("World_Imagery")], "tileSize": 256, "maxzoom": 18, "attribution": satelliteAttribution],
                "reference": ["type": "raster", "tiles": [tiles("Reference/World_Boundaries_and_Places")], "tileSize": 256, "maxzoom": 18],
            ]
            layers = [
                ["id": "background", "type": "background", "paint": ["background-color": backgroundHex]],
                ["id": "base", "type": "raster", "source": "base"],
                ["id": "reference", "type": "raster", "source": "reference", "paint": ["raster-opacity": 0.9]],
            ]
        case .street:
            sources = [
                "base": ["type": "raster", "tiles": [tiles("World_Street_Map")], "tileSize": 256, "maxzoom": 18, "attribution": streetAttribution],
            ]
            layers = [
                ["id": "background", "type": "background", "paint": ["background-color": backgroundHex]],
                ["id": "base", "type": "raster", "source": "base"],
            ]
        }
        let style: [String: Any] = ["version": 8, "name": "PulsIO \(basemap.rawValue)", "sources": sources, "layers": layers]
        let data = try! JSONSerialization.data(withJSONObject: style)   // static, well-formed by construction
        return String(decoding: data, as: UTF8.self)
    }

    /// Kept for the initial style.
    static var esriDarkGrayJSON: String { json(for: .dark) }
}
