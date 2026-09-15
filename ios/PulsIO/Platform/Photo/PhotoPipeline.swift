import CoreImage
import CoreImage.CIFilterBuiltins
import UIKit
import Vision

/// Everything that happens to a report photo before it leaves the phone (SPEC §11):
/// resize to ~1600 px, detect faces with Vision and blur them, optionally blur detected text regions (number
/// plates — this over-blurs shop signs, the safe failure), then JPEG at ~200 KB. The unblurred original
/// never leaves the device; the moderation model only ever sees the output of this.
enum PhotoPipeline {
    struct Result: Sendable {
        let jpeg: Data
        let pixelSize: CGSize
        let facesBlurred: Int
        let textRegionsBlurred: Int
    }

    struct Options: Sendable {
        var maxDimension: CGFloat = 1600
        var blurText = true
        var jpegQuality: CGFloat = 0.72
    }

    static func process(_ original: UIImage, options: Options = Options()) async throws -> Result {
        let resized = downscale(original, maxDimension: options.maxDimension)
        guard let cg = resized.cgImage else { throw Failure.noImage }

        // Vision works in normalised coordinates with the origin at the bottom-left.
        let faces = try detectFaces(in: cg)
        let text = options.blurText ? try detectText(in: cg) : []
        var regions = faces.map { grow($0, by: 0.25) }
        regions += text.map { grow($0, by: 0.15) }

        let output = regions.isEmpty ? CIImage(cgImage: cg) : blur(CIImage(cgImage: cg), regions: regions)
        let context = CIContext()
        guard let rendered = context.createCGImage(output, from: CIImage(cgImage: cg).extent) else { throw Failure.render }
        guard let jpeg = UIImage(cgImage: rendered).jpegData(compressionQuality: options.jpegQuality) else { throw Failure.encode }
        return Result(jpeg: jpeg, pixelSize: CGSize(width: cg.width, height: cg.height), facesBlurred: faces.count, textRegionsBlurred: text.count)
    }

    enum Failure: Error { case noImage, render, encode }

    // MARK: Steps

    /// Measured in PIXELS (a UIImage's `size` is points; camera and screen-scale images differ by 2–3×).
    /// Always re-renders at scale 1 with orientation baked in, so what follows sees a plain `.up` bitmap.
    static func downscale(_ image: UIImage, maxDimension: CGFloat) -> UIImage {
        let px = CGSize(width: CGFloat(image.cgImage?.width ?? Int(image.size.width * image.scale)),
                        height: CGFloat(image.cgImage?.height ?? Int(image.size.height * image.scale)))
        // Orientation swaps width/height for rotated camera captures.
        let oriented = [.left, .right, .leftMirrored, .rightMirrored].contains(image.imageOrientation) ? CGSize(width: px.height, height: px.width) : px
        let scale = min(1, maxDimension / max(oriented.width, oriented.height))
        let target = CGSize(width: (oriented.width * scale).rounded(), height: (oriented.height * scale).rounded())
        let format = UIGraphicsImageRendererFormat()
        format.scale = 1
        return UIGraphicsImageRenderer(size: target, format: format).image { _ in image.draw(in: CGRect(origin: .zero, size: target)) }
    }

    static func detectFaces(in image: CGImage) throws -> [CGRect] {
        let request = VNDetectFaceRectanglesRequest()
        pinToCPUIfSimulator(request)
        try VNImageRequestHandler(cgImage: image, orientation: .up).perform([request])
        return (request.results ?? []).map(\.boundingBox)
    }

    static func detectText(in image: CGImage) throws -> [CGRect] {
        let request = VNRecognizeTextRequest()
        request.recognitionLevel = .fast
        request.usesLanguageCorrection = false
        pinToCPUIfSimulator(request)
        try VNImageRequestHandler(cgImage: image, orientation: .up).perform([request])
        return (request.results ?? []).map(\.boundingBox)
    }

    /// The simulator has no Neural Engine and Vision's default device fails with "could not create inference
    /// context"; on device the default (ANE/GPU) is used.
    private static func pinToCPUIfSimulator(_ request: VNRequest) {
        #if targetEnvironment(simulator)
        guard let stages = try? request.supportedComputeStageDevices else { return }
        for (stage, devices) in stages {
            if let cpu = devices.first(where: { if case .cpu = $0 { return true } else { return false } }) {
                request.setComputeDevice(cpu, for: stage)
            }
        }
        #endif
    }

    private static func grow(_ r: CGRect, by fraction: CGFloat) -> CGRect {
        r.insetBy(dx: -r.width * fraction, dy: -r.height * fraction).intersection(CGRect(x: 0, y: 0, width: 1, height: 1))
    }

    /// Heavy gaussian blur composited back only inside the regions (a mask of white rounded rects).
    static func blur(_ image: CIImage, regions: [CGRect]) -> CIImage {
        let extent = image.extent
        let radius = max(12, min(extent.width, extent.height) / 40)
        let blurred = image.clampedToExtent().applyingGaussianBlur(sigma: radius).cropped(to: extent)

        var mask = CIImage(color: .black).cropped(to: extent)
        for r in regions {
            let px = CGRect(x: r.minX * extent.width, y: r.minY * extent.height, width: r.width * extent.width, height: r.height * extent.height)
            let patch = CIImage(color: .white).cropped(to: px)
            mask = patch.composited(over: mask)
        }
        // Soften the mask edge so the blur feathers in.
        mask = mask.clampedToExtent().applyingGaussianBlur(sigma: 6).cropped(to: extent)

        let blend = CIFilter.blendWithMask()
        blend.inputImage = blurred
        blend.backgroundImage = image
        blend.maskImage = mask
        return blend.outputImage ?? image
    }
}
