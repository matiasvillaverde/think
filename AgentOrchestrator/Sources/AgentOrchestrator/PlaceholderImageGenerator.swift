import CoreGraphics
import Foundation
#if canImport(UIKit)
import UIKit
#elseif canImport(AppKit)
import AppKit
#endif

/// Generates gradient placeholder images for loading states
internal struct PlaceholderImageGenerator: PlaceholderImageGenerating {
    // MARK: - Constants

    private let size: Int
    private let gradientStartRed: Float
    private let gradientStartGreen: Float
    private let gradientStartBlue: Float
    private let gradientEndBlue: Float

    // MARK: - Initialization

    internal init(
        size: Int = 512,
        gradientStartRed: Float = 128.0,
        gradientStartGreen: Float = 64.0,
        gradientStartBlue: Float = 128.0,
        gradientEndBlue: Float = 127.0
    ) {
        self.size = size
        self.gradientStartRed = gradientStartRed
        self.gradientStartGreen = gradientStartGreen
        self.gradientStartBlue = gradientStartBlue
        self.gradientEndBlue = gradientEndBlue
    }

    // MARK: - Public Methods

    internal func generatePlaceholderData() -> Data? {
        let pixelData: [UInt8] = createGradientPixelData()
        guard let cgImage = createCGImage(from: pixelData) else {
            return nil
        }
        return convertToImageData(cgImage: cgImage)
    }

    // MARK: - Private Methods

    private func createGradientPixelData() -> [UInt8] {
        let bytesPerPixel: Int = 4
        let maxColorValue: UInt8 = 255

        var pixelData: [UInt8] = []
        let totalPixels: Int = size * size * bytesPerPixel
        pixelData.reserveCapacity(totalPixels)

        for row in 0..<size {
            let progress: Float = Float(row) / Float(size)
            let red: UInt8 = UInt8(gradientStartRed * (1.0 - progress))
            let green: UInt8 = UInt8(gradientStartGreen * (1.0 - progress))
            let blue: UInt8 = UInt8(gradientStartBlue + gradientEndBlue * progress)

            for _ in 0..<size {
                pixelData.append(red)
                pixelData.append(green)
                pixelData.append(blue)
                pixelData.append(maxColorValue)
            }
        }
        return pixelData
    }

    private func createCGImage(from pixelData: [UInt8]) -> CGImage? {
        let bytesPerPixel: Int = 4
        let bitsPerComponent: Int = 8

        var mutablePixelData: [UInt8] = pixelData
        let bytesPerRow: Int = size * bytesPerPixel
        let colorSpace: CGColorSpace = CGColorSpaceCreateDeviceRGB()
        let bitmapInfo: CGBitmapInfo = CGBitmapInfo(
            rawValue: CGImageAlphaInfo.premultipliedLast.rawValue
        )

        guard let context = CGContext(
            data: &mutablePixelData,
            width: size,
            height: size,
            bitsPerComponent: bitsPerComponent,
            bytesPerRow: bytesPerRow,
            space: colorSpace,
            bitmapInfo: bitmapInfo.rawValue
        ) else {
            return nil
        }

        return context.makeImage()
    }

    private func convertToImageData(cgImage: CGImage) -> Data? {
        #if canImport(UIKit)
        let image: UIImage = UIImage(cgImage: cgImage)
        return image.pngData()
        #elseif canImport(AppKit)
        let nsSize: NSSize = NSSize(width: size, height: size)
        let image: NSImage = NSImage(cgImage: cgImage, size: nsSize)
        return image.tiffRepresentation
        #endif
    }
}
