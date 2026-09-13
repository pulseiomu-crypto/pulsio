import CoreImage
import CoreImage.CIFilterBuiltins
import UIKit

/// A crisp QR for the card's "way back" link — rendered at the exact pixel size, no interpolation.
enum QRCode {
    static func image(for text: String, pixels: Int, foreground: UIColor, background: UIColor) -> UIImage? {
        let filter = CIFilter.qrCodeGenerator()
        filter.message = Data(text.utf8)
        filter.correctionLevel = "M"
        guard let base = filter.outputImage else { return nil }
        let scale = CGFloat(pixels) / base.extent.width
        let scaled = base.transformed(by: CGAffineTransform(scaleX: scale, y: scale))
        let tint = CIFilter.falseColor()
        tint.inputImage = scaled
        tint.color0 = CIColor(color: foreground)
        tint.color1 = CIColor(color: background)
        guard let output = tint.outputImage, let cg = CIContext().createCGImage(output, from: output.extent) else { return nil }
        return UIImage(cgImage: cg)
    }
}
