import CoreImage
import CoreImage.CIFilterBuiltins
import Foundation
import MLX

internal enum MediaProcessing {

    private static let context = CIContext()

    internal static func inSRGBToneCurveSpace(_ image: CIImage) -> CIImage {
        let filter = CIFilter.linearToSRGBToneCurve()
        filter.inputImage = image
        return filter.outputImage ?? image
    }

    internal static func resampleBicubic(_ image: CIImage, to size: CGSize) -> CIImage {
        let yScale = size.height / image.extent.height
        let xScale = size.width / image.extent.width

        let filter = CIFilter.bicubicScaleTransform()
        filter.inputImage = image
        filter.scale = Float(yScale)
        filter.aspectRatio = Float(xScale / yScale)
        let scaledImage = filter.outputImage ?? image

        let exactRect = CGRect(
            x: 0,
            y: 0,
            width: size.width,
            height: size.height
        )

        return scaledImage.cropped(to: exactRect)
    }

    internal static func normalize(
        _ image: CIImage, mean: (CGFloat, CGFloat, CGFloat), std: (CGFloat, CGFloat, CGFloat)
    ) -> CIImage {
        let filter = CIFilter.colorMatrix()
        filter.inputImage = image
        filter.rVector = .init(x: 1 / std.0, y: 0, z: 0, w: 0)
        filter.gVector = .init(x: 0, y: 1 / std.1, z: 0, w: 0)
        filter.bVector = .init(x: 0, y: 0, z: 1 / std.2, w: 0)
        filter.aVector = .init(x: 0, y: 0, z: 0, w: 1)
        filter.biasVector = .init(
            x: -mean.0 / std.0,
            y: -mean.1 / std.1,
            z: -mean.2 / std.2,
            w: 0
        )
        return filter.outputImage ?? image
    }

    internal static func asMLXArray(_ image: CIImage, colorSpace: CGColorSpace? = nil) -> MLXArray {
        let size = image.extent.size
        let width = Int(size.width.rounded())
        let height = Int(size.height.rounded())

        let format = CIFormat.RGBAf
        let componentsPerPixel = 4
        let bytesPerPixel = componentsPerPixel * 4
        let bytesPerRow = width * bytesPerPixel

        var data = Data(count: width * height * bytesPerPixel)
        data.withUnsafeMutableBytes { ptr in
            context.render(
                image,
                toBitmap: ptr.baseAddress!,
                rowBytes: bytesPerRow,
                bounds: image.extent,
                format: format,
                colorSpace: colorSpace
            )
            context.clearCaches()
        }

        var array = MLXArray(data, [height, width, 4], type: Float32.self)
        array = array[0..., 0..., ..<3]
        array = array.reshaped(1, height, width, 3).transposed(0, 3, 1, 2)
        return array
    }

    internal static func centerCrop(_ image: CIImage, size: CGSize) -> CIImage {
        let extent = image.extent
        let targetWidth = min(extent.width, size.width)
        let targetHeight = min(extent.height, size.height)
        let crop = CGRect(
            x: (extent.maxX - targetWidth) / 2,
            y: (extent.maxY - targetHeight) / 2,
            width: targetWidth,
            height: targetHeight
        )
        return image
            .cropped(to: crop)
            .transformed(by: CGAffineTransform(translationX: -crop.minX, y: -crop.minY))
    }

    internal static func padToSize(
        _ image: CIImage,
        size: CGSize,
        backgroundColor: CIColor = .black
    ) -> CIImage {
        let rect = CGRect(origin: .zero, size: size)
        let background = CIImage(color: backgroundColor).cropped(to: rect)
        let translated = image.transformed(
            by: CGAffineTransform(
                translationX: -image.extent.origin.x,
                y: -image.extent.origin.y
            )
        )
        return translated.composited(over: background)
    }

    internal static func apply(_ image: CIImage, processing: UserInput.Processing?) -> CIImage {
        var image = image

        if let resize = processing?.resize {
            let scale = min(resize.width / image.extent.width, resize.height / image.extent.height)
            image = image.transformed(by: CGAffineTransform(scaleX: scale, y: scale))
        }

        return image
    }
}
