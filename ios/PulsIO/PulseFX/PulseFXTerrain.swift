import CoreGraphics
import Foundation
import ImageIO
import UIKit

/// The baked heightmap: `MauritiusHeightmap` (256×366, 8-bit grey; 0 = sea, 255 = 964 m, Web Mercator).
/// Baked ONCE at load: coastline mask, NW-lit hillshade relief, and how far the wave must travel.
/// Nothing per-pixel happens per frame.
final class PulseFXTerrain: Sendable {
    struct BBox: Sendable { let w, s, e, n: Double }
    static let bbox = BBox(w: 57.267609, s: -20.538935, e: 57.822418, n: -19.795133)
    static let cols = 256, rows = 366

    let heights: [UInt8]
    let mask: CGImage
    let relief: CGImage
    /// Furthest land from the impact point, as a multiple of the island rect's height (p99, ×1.15).
    let landReach: Double

    static func loadFromBundle() -> PulseFXTerrain? {
        guard let asset = NSDataAsset(name: "MauritiusHeightmap"),
              let source = CGImageSourceCreateWithData(asset.data as CFData, nil),
              let image = CGImageSourceCreateImageAtIndex(source, 0, nil) else { return nil }
        return PulseFXTerrain(image: image)
    }

    init?(image: CGImage) {
        let w = Self.cols, h = Self.rows
        var grey = [UInt8](repeating: 0, count: w * h)
        let ok = grey.withUnsafeMutableBytes { buf -> Bool in
            guard let ctx = CGContext(data: buf.baseAddress, width: w, height: h, bitsPerComponent: 8, bytesPerRow: w,
                                      space: CGColorSpaceCreateDeviceGray(), bitmapInfo: CGImageAlphaInfo.none.rawValue) else { return false }
            ctx.draw(image, in: CGRect(x: 0, y: 0, width: w, height: h))
            return true
        }
        guard ok else { return nil }
        heights = grey

        func hAt(_ x: Int, _ y: Int) -> Double {
            let cx = min(max(x, 0), w - 1), cy = min(max(y, 0), h - 1)
            return Double(grey[cy * w + cx]) / 255
        }

        var maskPx = [UInt8](repeating: 0, count: w * h * 4)
        var reliefPx = [UInt8](repeating: 0, count: w * h * 4)
        for y in 0..<h {
            for x in 0..<w {
                let i = (y * w + x) * 4
                let hv = hAt(x, y)
                // Feathered coastline — the 143 m/px DEM coast never lines up exactly with the tiles' vector coast.
                let a = PulseFXChoreography.smooth(0.004, 0.055, hv)
                maskPx[i] = 255; maskPx[i + 1] = 255; maskPx[i + 2] = 255; maskPx[i + 3] = UInt8(a * 255)
                // Hillshade, light from the NW.
                let dx = hAt(x + 1, y) - hAt(x - 1, y)
                let dy = hAt(x, y + 1) - hAt(x, y - 1)
                let sh = PulseFXChoreography.clamp01(0.5 + (dx + dy) * 4.2)
                let slope = min(1, (abs(dx) + abs(dy)) * 9)
                let ra = a * (0.10 + slope * 0.55)
                // Premultiplied RGBA for CGImage.
                reliefPx[i] = UInt8(sh * 90 * ra); reliefPx[i + 1] = UInt8((140 + sh * 115) * ra)
                reliefPx[i + 2] = UInt8((120 + sh * 95) * ra); reliefPx[i + 3] = UInt8(ra * 255)
            }
        }
        guard let maskImage = Self.rgbaImage(maskPx, w, h), let reliefImage = Self.rgbaImage(reliefPx, w, h) else { return nil }
        mask = maskImage
        relief = reliefImage

        // Travel: p99 of land distance from the heart (not the max — Round Island is ~30 km off the north coast).
        let bb = Self.bbox
        let aspect = ((bb.e - bb.w) / 360) / (PulseFXChoreography.mercY(bb.s) - PulseFXChoreography.mercY(bb.n))
        let hu = (PulseFXChoreography.islandHeart.lng - bb.w) / (bb.e - bb.w)
        let hv = (PulseFXChoreography.mercY(PulseFXChoreography.islandHeart.lat) - PulseFXChoreography.mercY(bb.n))
            / (PulseFXChoreography.mercY(bb.s) - PulseFXChoreography.mercY(bb.n))
        var ds: [Double] = []
        ds.reserveCapacity(w * h / 4)
        for y in 0..<h {
            for x in 0..<w where hAt(x, y) > 0.004 {
                let du = (Double(x) / Double(w - 1) - hu) * aspect
                let dv = (Double(y) / Double(h - 1) - hv) / PulseFXChoreography.waveFlat
                ds.append((du * du + dv * dv).squareRoot())
            }
        }
        ds.sort()
        landReach = ds.isEmpty ? 1 : ds[min(ds.count - 1, Int(Double(ds.count) * 0.99))] * 1.15
    }

    private static func rgbaImage(_ px: [UInt8], _ w: Int, _ h: Int) -> CGImage? {
        let data = Data(px) as CFData
        guard let provider = CGDataProvider(data: data) else { return nil }
        return CGImage(width: w, height: h, bitsPerComponent: 8, bitsPerPixel: 32, bytesPerRow: w * 4,
                       space: CGColorSpaceCreateDeviceRGB(),
                       bitmapInfo: CGBitmapInfo(rawValue: CGImageAlphaInfo.premultipliedLast.rawValue),
                       provider: provider, decode: nil, shouldInterpolate: true, intent: .defaultIntent)
    }

    /// Screen-space bilinear sample of the heightmap in its on-screen rect `r`. Exact, because the heightmap is
    /// linear in Web Mercator and so is the screen at bearing 0 / pitch 0.
    func sampleHeight(at p: CGPoint, in r: CGRect) -> Double {
        let u = (p.x - r.minX) / r.width * CGFloat(Self.cols - 1)
        let v = (p.y - r.minY) / r.height * CGFloat(Self.rows - 1)
        guard u >= 0, v >= 0, u <= CGFloat(Self.cols - 1), v <= CGFloat(Self.rows - 1) else { return 0 }
        let x0 = Int(u), y0 = Int(v)
        let fx = Double(u) - Double(x0), fy = Double(v) - Double(y0)
        func h(_ x: Int, _ y: Int) -> Double {
            Double(heights[min(y, Self.rows - 1) * Self.cols + min(x, Self.cols - 1)]) / 255
        }
        let a = h(x0, y0), b = h(x0 + 1, y0), c = h(x0, y0 + 1), d = h(x0 + 1, y0 + 1)
        return (a + (b - a) * fx) * (1 - fy) + (c + (d - c) * fx) * fy
    }
}
