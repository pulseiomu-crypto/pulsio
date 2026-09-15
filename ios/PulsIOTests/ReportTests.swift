import CoreLocation
import Foundation
import Testing
import UIKit
@testable import PulsIO

/// The photo never leaves the phone un-blurred: resize, and blur the regions Vision finds.
struct PhotoPipelineTests {
    /// A synthetic scene with a number plate — Vision finds the text, the pipeline blurs it.
    private func plateScene() -> UIImage {
        let size = CGSize(width: 2400, height: 1800)
        return UIGraphicsImageRenderer(size: size).image { ctx in
            UIColor(white: 0.45, alpha: 1).setFill(); ctx.fill(CGRect(origin: .zero, size: size))
            UIColor.white.setFill(); ctx.fill(CGRect(x: 1500, y: 1350, width: 520, height: 160))
            ("AB 1234" as NSString).draw(at: CGPoint(x: 1530, y: 1365), withAttributes: [.font: UIFont.boldSystemFont(ofSize: 120), .foregroundColor: UIColor.black])
        }
    }

    /// Mean absolute difference between neighbouring pixels in a region — sharp text is high, blur is low.
    private func sharpness(of image: UIImage, in rect: CGRect) -> Double {
        guard let cg = image.cgImage?.cropping(to: rect) else { return 0 }
        let w = cg.width, h = cg.height
        var px = [UInt8](repeating: 0, count: w * h)
        px.withUnsafeMutableBytes { buf in
            let ctx = CGContext(data: buf.baseAddress, width: w, height: h, bitsPerComponent: 8, bytesPerRow: w, space: CGColorSpaceCreateDeviceGray(), bitmapInfo: CGImageAlphaInfo.none.rawValue)!
            ctx.draw(cg, in: CGRect(x: 0, y: 0, width: w, height: h))
        }
        var acc = 0.0
        for y in 0..<h { for x in 1..<w { acc += abs(Double(px[y * w + x]) - Double(px[y * w + x - 1])) } }
        return acc / Double(w * h)
    }

    @Test func downscalesTo1600AndBlursThePlate() async throws {
        let original = plateScene()
        let result = try await PhotoPipeline.process(original)
        #expect(max(result.pixelSize.width, result.pixelSize.height) == 1600)
        #expect(result.textRegionsBlurred >= 1, "Vision should find the plate text")
        #expect(result.jpeg.count < 600_000)

        let output = try #require(UIImage(data: result.jpeg))
        // The plate sits at (1500…2020, 1350…1510) in a 2400-wide frame → scale by 1600/2400.
        let plate = CGRect(x: 1000, y: 900, width: 346, height: 106)
        let before = sharpness(of: PhotoPipeline.downscale(original, maxDimension: 1600), in: plate)
        let after = sharpness(of: output, in: plate)
        #expect(after < before * 0.4, "plate should be much softer after the blur (\(before) → \(after))")
    }

    @Test func leavesAPlainSceneAlone() async throws {
        let format = UIGraphicsImageRendererFormat(); format.scale = 1
        let plain = UIGraphicsImageRenderer(size: CGSize(width: 800, height: 600), format: format).image { ctx in UIColor.gray.setFill(); ctx.fill(CGRect(x: 0, y: 0, width: 800, height: 600)) }
        let result = try await PhotoPipeline.process(plain)
        #expect(result.facesBlurred == 0 && result.textRegionsBlurred == 0)
        #expect(result.pixelSize == CGSize(width: 800, height: 600))   // never upscaled
    }
}

struct ReportModelTests {
    @Test func decodesTheRowAndChecksTheRadiusOnDevice() throws {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        let r = try decoder.decode(Report.self, from: Data(#"""
        {"id":7,"user_id":"6f1c2d3e-4a5b-4c6d-8e7f-901234567890","category":"flood","description":"Royal Road under water","lat":-20.3162,"lng":57.5203,
         "district":"Plaines Wilhems","status":"unconfirmed","confirmations":1,"confirmed_by":["1f1c2d3e-4a5b-4c6d-8e7f-901234567890"],"flag_count":0,
         "image_path":"6f1c/one.jpg","image_url":null,"model_verdict":"pass","created_at":"2026-09-13T16:00:00Z","expires_at":"2026-09-13T18:00:00Z"}
        """#.utf8))
        #expect(r.category == .flood && r.status == .unconfirmed && r.district == .plainesWilhems && r.status.isLive)
        #expect(r.isWithinConfirmRadius(of: CLLocationCoordinate2D(latitude: -20.3200, longitude: 57.5250)))   // ~650 m
        #expect(!r.isWithinConfirmRadius(of: CLLocationCoordinate2D(latitude: -20.16, longitude: 57.50)))       // Port Louis, ~17 km
        #expect(r.markerID == "report-7")
    }

    @Test func unknownStatusAndCategoryStaySafe() throws {
        let r = try JSONDecoder().decode(Report.self, from: Data(#"{"id":1,"category":"meteor","lat":-20.2,"lng":57.5,"status":"published"}"#.utf8))
        #expect(r.category == .other && r.status == .pending && !r.status.isLive)   // unknown status is never shown as live
    }

    @Test func contractsMirrorTheServer() {
        #expect(ReportCategory.allCases.map(\.rawValue) == ["power_cut","water_cut","accident","hazard","flood","traffic","jellyfish","event","infrastructure","other"])
        #expect(ReportRules.confirmRadiusMetres == 2000 && ReportRules.flagsToHide == 2 && ReportRules.confirmationsToConfirm == 2)
        #expect(ReportCode(rawValue: "U-213") == .tooFar)
    }
}
