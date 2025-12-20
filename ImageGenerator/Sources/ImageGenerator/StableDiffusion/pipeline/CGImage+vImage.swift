import Accelerate
import CoreGraphics
import CoreML
import Foundation

@available(iOS 16.0, macOS 13.0, *)
extension CGImage {
    typealias PixelBufferPFx1 = vImage.PixelBuffer<vImage.PlanarF>
    typealias PixelBufferP8x3 = vImage.PixelBuffer<vImage.Planar8x3>
    typealias PixelBufferIFx3 = vImage.PixelBuffer<vImage.InterleavedFx3>
    typealias PixelBufferI8x3 = vImage.PixelBuffer<vImage.Interleaved8x3>

    public enum ShapedArrayError: String, Swift.Error {
        case wrongNumberOfChannels
        case incorrectFormatsConvertingToShapedArray
        case vImageConverterNotInitialized
    }

    public static func fromShapedArray(_ array: MLShapedArray<Float32>) throws -> CGImage {
        // array is [N,C,H,W], where C==3
        let channelCount = array.shape[1]
        guard channelCount == 3 else {
            throw ShapedArrayError.wrongNumberOfChannels
        }

        let height = array.shape[2]
        let width = array.shape[3]

        // Normalize each channel into a float between 0 and 1.0
        let floatChannels = (0..<channelCount).map { i in
            // Normalized channel output
            let cOut = PixelBufferPFx1(width: width, height: height)

            // Reference this channel in the array and normalize
            array[0][i].withUnsafeShapedBufferPointer { ptr, _, strides in
                let cIn = PixelBufferPFx1(data: .init(mutating: ptr.baseAddress!),
                                          width: width, height: height,
                                          byteCountPerRow: strides[0] * 4)
                // Map [-1.0 1.0] -> [0.0 1.0]
                cIn.multiply(by: 0.5, preBias: 1.0, postBias: 0.0, destination: cOut)
            }
            return cOut
        }

        // Convert to interleaved and then to UInt8
        let floatImage = PixelBufferIFx3(planarBuffers: floatChannels)
        let uint8Image = PixelBufferI8x3(width: width, height: height)
        floatImage.convert(to: uint8Image) // maps [0.0 1.0] -> [0 255] and clips

        // Convert to uint8x3 to RGB CGImage (no alpha)
        let bitmapInfo = CGBitmapInfo(rawValue: CGImageAlphaInfo.none.rawValue)
        return uint8Image.makeCGImage(cgImageFormat:
                .init(bitsPerComponent: 8,
                      bitsPerPixel: 3 * 8,
                      colorSpace: CGColorSpace(name: CGColorSpace.sRGB) ?? CGColorSpaceCreateDeviceRGB(),
                      bitmapInfo: bitmapInfo)!)!
    }

    public func planarRGBShapedArray(minValue: Float, maxValue: Float)
        throws -> MLShapedArray<Float32> {
        let formatInfo = try prepareImageFormats()
        let mediumDestination = try convertToMediumFormat(
            width: formatInfo.width,
            height: formatInfo.height,
            mediumFormat: formatInfo.mediumFormat
        )
        let planarBuffers = try createPlanarBuffers(width: formatInfo.width, height: formatInfo.height)
        convertToPlanarFloat(
            mediumDestination: mediumDestination,
            planarBuffers: planarBuffers,
            minValue: minValue,
            maxValue: maxValue
        )
        processAlphaChannel(planarBuffers: planarBuffers, width: formatInfo.width, height: formatInfo.height)
        return combineChannelsToShapedArray(planarBuffers: planarBuffers)
    }

    /// Contains image format information
    private struct ImageFormatInfo {
        let width: vImagePixelCount
        let height: vImagePixelCount
        let mediumFormat: vImage_CGImageFormat
    }

    /// Contains RGB channel data
    private struct RGBChannels {
        let red: [Float]
        let green: [Float]
        let blue: [Float]
    }

    /// Prepares image formats and validates dimensions
    private func prepareImageFormats() throws -> ImageFormatInfo {
        guard
            let mediumFormat = vImage_CGImageFormat(
                bitsPerComponent: 8 * MemoryLayout<UInt8>.size,
                bitsPerPixel: 8 * MemoryLayout<UInt8>.size * 4,
                colorSpace: CGColorSpaceCreateDeviceRGB(),
                bitmapInfo: CGBitmapInfo(rawValue: CGImageAlphaInfo.first.rawValue)),
            let width = vImagePixelCount(exactly: self.width),
            let height = vImagePixelCount(exactly: self.height)
        else {
            throw ShapedArrayError.incorrectFormatsConvertingToShapedArray
        }
        return ImageFormatInfo(width: width, height: height, mediumFormat: mediumFormat)
    }

    /// Converts the source image to medium format
    private func convertToMediumFormat(
        width: vImagePixelCount,
        height: vImagePixelCount,
        mediumFormat: vImage_CGImageFormat
    ) throws -> vImage_Buffer {
        guard var sourceFormat = vImage_CGImageFormat(cgImage: self) else {
            throw ShapedArrayError.incorrectFormatsConvertingToShapedArray
        }

        var sourceImageBuffer = try vImage_Buffer(cgImage: self)
        var mediumDestination = try vImage_Buffer(
            width: Int(width),
            height: Int(height),
            bitsPerPixel: mediumFormat.bitsPerPixel
        )

        var mutableMediumFormat = mediumFormat
        let converter = vImageConverter_CreateWithCGImageFormat(
            &sourceFormat,
            &mutableMediumFormat,
            nil,
            vImage_Flags(kvImagePrintDiagnosticsToConsole),
            nil)

        guard let converter = converter?.takeRetainedValue() else {
            throw ShapedArrayError.vImageConverterNotInitialized
        }

        vImageConvert_AnyToAny(
            converter,
            &sourceImageBuffer,
            &mediumDestination,
            nil,
            vImage_Flags(kvImagePrintDiagnosticsToConsole)
        )

        return mediumDestination
    }

    /// Container for planar ARGB buffers
    private struct PlanarBuffers {
        var alpha: vImage_Buffer
        var red: vImage_Buffer
        var green: vImage_Buffer
        var blue: vImage_Buffer
    }

    /// Creates planar buffers for ARGB channels
    private func createPlanarBuffers(width: vImagePixelCount, height: vImagePixelCount) throws -> PlanarBuffers {
        let bitsPerPixel = 8 * UInt32(MemoryLayout<Float>.size)
        return try PlanarBuffers(
            alpha: vImage_Buffer(width: Int(width), height: Int(height), bitsPerPixel: bitsPerPixel),
            red: vImage_Buffer(width: Int(width), height: Int(height), bitsPerPixel: bitsPerPixel),
            green: vImage_Buffer(width: Int(width), height: Int(height), bitsPerPixel: bitsPerPixel),
            blue: vImage_Buffer(width: Int(width), height: Int(height), bitsPerPixel: bitsPerPixel)
        )
    }

    /// Converts ARGB8888 to planar float format
    private func convertToPlanarFloat(
        mediumDestination: vImage_Buffer,
        planarBuffers: PlanarBuffers,
        minValue: Float,
        maxValue: Float
    ) {
        var mediumDest = mediumDestination
        var destA = planarBuffers.alpha
        var destR = planarBuffers.red
        var destG = planarBuffers.green
        var destB = planarBuffers.blue
        var minFloat: [Float] = Array(repeating: minValue, count: 4)
        var maxFloat: [Float] = Array(repeating: maxValue, count: 4)

        vImageConvert_ARGB8888toPlanarF(
            &mediumDest,
            &destA,
            &destR,
            &destG,
            &destB,
            &maxFloat,
            &minFloat,
            .zero
        )
    }

    /// Processes alpha channel by setting RGB values to -1 where alpha is 0
    private func processAlphaChannel(planarBuffers: PlanarBuffers, width: vImagePixelCount, height: vImagePixelCount) {
        let destAPtr = planarBuffers.alpha.data.assumingMemoryBound(to: Float.self)
        let destRPtr = planarBuffers.red.data.assumingMemoryBound(to: Float.self)
        let destGPtr = planarBuffers.green.data.assumingMemoryBound(to: Float.self)
        let destBPtr = planarBuffers.blue.data.assumingMemoryBound(to: Float.self)

        for i in 0..<Int(width) * Int(height) where destAPtr.advanced(by: i).pointee == 0 {
            destRPtr.advanced(by: i).pointee = -1
            destGPtr.advanced(by: i).pointee = -1
            destBPtr.advanced(by: i).pointee = -1
        }
    }

    /// Combines RGB channels into a shaped array
    private func combineChannelsToShapedArray(planarBuffers: PlanarBuffers) -> MLShapedArray<Float32> {
        let redData = planarBuffers.red.unpaddedData()
        let greenData = planarBuffers.green.unpaddedData()
        let blueData = planarBuffers.blue.unpaddedData()
        let imageData = redData + greenData + blueData
        return MLShapedArray<Float32>(data: imageData, shape: [1, 3, self.height, self.width])
    }

    private func normalizePixelValues(pixel: UInt8) -> Float {
        (Float(pixel) / 127.5) - 1.0
    }

    public func toRGBShapedArray(minValue: Float, maxValue _: Float)
        throws -> MLShapedArray<Float32> {
        let width = self.width
        let height = self.height

        guard let context = createRGBContext(width: width, height: height),
              let ptr = context.data?.bindMemory(to: UInt8.self, capacity: width * height * 4) else {
            return []
        }

        context.draw(self, in: CGRect(x: 0, y: 0, width: width, height: height))

        let channels = extractRGBChannels(
            from: ptr,
            width: width,
            height: height,
            alphaMaskValue: minValue
        )

        return createShapedArrayFromChannels(
            channels: channels,
            width: width,
            height: height
        )
    }

    /// Creates an RGB context for image processing
    private func createRGBContext(width: Int, height: Int) -> CGContext? {
        guard let colorSpace = CGColorSpace(name: CGColorSpace.sRGB) else { return nil }

        return CGContext(
            data: nil,
            width: width,
            height: height,
            bitsPerComponent: 8,
            bytesPerRow: 4 * width,
            space: colorSpace,
            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
        )
    }

    /// Extracts RGB channels from pixel data
    private func extractRGBChannels(
        from ptr: UnsafeMutablePointer<UInt8>,
        width: Int,
        height: Int,
        alphaMaskValue: Float
    ) -> RGBChannels {
        var redChannel = [Float](repeating: 0, count: width * height)
        var greenChannel = [Float](repeating: 0, count: width * height)
        var blueChannel = [Float](repeating: 0, count: width * height)

        for y in 0..<height {
            for x in 0..<width {
                let i = 4 * (y * width + x)
                let pixelIndex = y * width + x

                if ptr[i + 3] == 0 {
                    // Alpha mask for controlnets
                    redChannel[pixelIndex] = alphaMaskValue
                    greenChannel[pixelIndex] = alphaMaskValue
                    blueChannel[pixelIndex] = alphaMaskValue
                } else {
                    redChannel[pixelIndex] = normalizePixelValues(pixel: ptr[i])
                    greenChannel[pixelIndex] = normalizePixelValues(pixel: ptr[i + 1])
                    blueChannel[pixelIndex] = normalizePixelValues(pixel: ptr[i + 2])
                }
            }
        }

        return RGBChannels(red: redChannel, green: greenChannel, blue: blueChannel)
    }

    /// Creates shaped array from RGB channels
    private func createShapedArrayFromChannels(
        channels: RGBChannels,
        width: Int,
        height: Int
    ) -> MLShapedArray<Float32> {
        let colorShape = [1, 1, height, width]
        let redShapedArray = MLShapedArray<Float32>(scalars: channels.red, shape: colorShape)
        let greenShapedArray = MLShapedArray<Float32>(scalars: channels.green, shape: colorShape)
        let blueShapedArray = MLShapedArray<Float32>(scalars: channels.blue, shape: colorShape)

        return MLShapedArray<Float32>(
            concatenating: [redShapedArray, greenShapedArray, blueShapedArray],
            alongAxis: 1
        )
    }
}

extension vImage_Buffer {
    func unpaddedData() -> Data {
        let bytesPerPixel = self.rowBytes / Int(self.width)
        let bytesPerRow = Int(self.width) * bytesPerPixel

        var contiguousPixelData = Data(capacity: bytesPerRow * Int(self.height))
        for row in 0..<Int(self.height) {
            let rowStart = self.data!.advanced(by: row * self.rowBytes)
            let rowData = Data(bytes: rowStart, count: bytesPerRow)
            contiguousPixelData.append(rowData)
        }

        return contiguousPixelData
    }
}
