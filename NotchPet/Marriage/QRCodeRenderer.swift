import AppKit
import CoreImage
import CoreImage.CIFilterBuiltins
import SwiftUI

/// Minimal QR code renderer on top of `CIFilter.qrCodeGenerator`. Keeps
/// the output pixel-sharp (nearest-neighbor scaling) so the QR blends
/// with NotchPet's pixel-art aesthetic.
enum QRCodeRenderer {
    /// Render a string to a CGImage at the requested on-screen size.
    /// Returns nil if CoreImage can't produce a bitmap (extremely rare).
    static func cgImage(from string: String,
                        size: CGFloat = 220) -> CGImage? {
        let filter = CIFilter.qrCodeGenerator()
        filter.message = Data(string.utf8)
        filter.correctionLevel = "M"

        guard let outputImage = filter.outputImage else { return nil }

        // Scale the tiny base image up so each module is many pixels.
        let scale = size / outputImage.extent.width
        let scaled = outputImage.transformed(by: CGAffineTransform(scaleX: scale, y: scale))

        let ctx = CIContext()
        return ctx.createCGImage(scaled, from: scaled.extent)
    }

    /// SwiftUI-friendly variant that returns an `Image`. Falls back to
    /// an empty image on failure (the QR tab will show a placeholder).
    static func image(from string: String, size: CGFloat = 220) -> Image {
        if let cg = cgImage(from: string, size: size) {
            return Image(decorative: cg, scale: 1.0)
                .interpolation(.none)
        }
        return Image(systemName: "qrcode")
    }
}
