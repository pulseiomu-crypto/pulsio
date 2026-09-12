import Foundation

/// The basemap style as a MapLibre style document. ESRI's dark gray canvas (free, no key) — Carto's keyless
/// tiles now carry an "API KEY REQUIRED" watermark, which is why NerveCentre moved to ESRI too.
/// Attribution strings here feed MapLibre's ⓘ button; the always-visible strip lives in the Map feature.
enum MapStyle {
    static let backgroundHex = "#060E18"   // Palette.abyss

    private static let esriBase = "https://server.arcgisonline.com/ArcGIS/rest/services/Canvas/World_Dark_Gray_Base/MapServer/tile/{z}/{y}/{x}"
    private static let esriReference = "https://server.arcgisonline.com/ArcGIS/rest/services/Canvas/World_Dark_Gray_Reference/MapServer/tile/{z}/{y}/{x}"
    static let esriAttribution = "Basemap © Esri, HERE, Garmin, FAO, NOAA, USGS, © OpenStreetMap contributors"

    static var esriDarkGrayJSON: String {
        let style: [String: Any] = [
            "version": 8,
            "name": "PulsIO dark",
            "sources": [
                "esri-dark-base": [
                    "type": "raster", "tiles": [esriBase], "tileSize": 256, "maxzoom": 16, "attribution": esriAttribution,
                ],
                "esri-dark-reference": [
                    "type": "raster", "tiles": [esriReference], "tileSize": 256, "maxzoom": 16,
                ],
            ],
            "layers": [
                ["id": "background", "type": "background", "paint": ["background-color": backgroundHex]],
                // Pulled toward the app's abyss: darker and slightly desaturated, so semantic pins stay the loudest thing.
                ["id": "esri-dark-base", "type": "raster", "source": "esri-dark-base",
                 "paint": ["raster-brightness-max": 0.72, "raster-saturation": -0.2, "raster-contrast": 0.05]],
                ["id": "esri-dark-reference", "type": "raster", "source": "esri-dark-reference",
                 "paint": ["raster-opacity": 0.85]],
            ],
        ]
        let data = try! JSONSerialization.data(withJSONObject: style)   // static, well-formed by construction
        return String(decoding: data, as: UTF8.self)
    }
}
