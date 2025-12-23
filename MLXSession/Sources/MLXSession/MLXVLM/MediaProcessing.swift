@preconcurrency import AVFoundation
import CoreImage
import CoreImage.CIFilterBuiltins
import Foundation
import MLX

internal typealias VideoFrame = UserInput.VideoFrame

internal struct ProcessedFrames {
    internal let frames: [MLXArray]
    internal let timestamps: [CMTime]
    internal let totalDuration: CMTime
}

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

    private static func validateAsset(_ asset: AVAsset) async throws {
        let tracks = try await asset.loadTracks(withMediaType: .video)

        guard !tracks.isEmpty,
            let videoTrack = tracks.first
        else { throw VLMError.noVideoTrackFound }

        let isDecodable = try await videoTrack.load(.isDecodable)

        if !isDecodable {
            throw VLMError.videoNotDecodable
        }
    }

    internal static func asProcessedSequence(
        _ video: UserInput.Video,
        samplesPerSecond: Int,
        frameProcessing: (VideoFrame) throws -> VideoFrame = { $0 }
    ) async throws -> ProcessedFrames {
        return try await asProcessedSequence(
            video,
            targetFPS: { _ in Double(samplesPerSecond) },
            maxFrames: Int.max,
            frameProcessing: frameProcessing
        )
    }

    internal static func asProcessedSequence(
        _ video: UserInput.Video,
        targetFPS: (CMTime) -> Double,
        maxFrames: Int = Int.max,
        frameProcessing: (VideoFrame) throws -> VideoFrame = { $0 }
    ) async throws -> ProcessedFrames {
        switch video {
        case .avAsset(let asset):
            try await validateAsset(asset)
            return try await _asProcessedSequence(
                asset, maxFrames: maxFrames, targetFPS: targetFPS, frameProcessing: frameProcessing)
        case .url(let url):
            let asset = AVURLAsset(url: url)
            try await validateAsset(asset)
            return try await _asProcessedSequence(
                asset, maxFrames: maxFrames, targetFPS: targetFPS, frameProcessing: frameProcessing)
        case .frames(let frames):
            return try await _asProcessedSequence(
                frames, targetFPS: targetFPS, frameProcessing: frameProcessing)
        }
    }

    private static func _asProcessedSequence(
        _ asset: AVAsset,
        maxFrames: Int,
        targetFPS: (CMTime) -> Double,
        frameProcessing: (VideoFrame) throws -> VideoFrame = { $0 }
    ) async throws -> ProcessedFrames {
        let generator = AVAssetImageGenerator(asset: asset)
        generator.appliesPreferredTrackTransform = true
        generator.requestedTimeToleranceBefore = .zero
        generator.requestedTimeToleranceAfter = .zero

        guard let duration = try? await asset.load(.duration) else {
            throw VLMError.processing("Failed to load the asset's duration.")
        }
        let fps = targetFPS(duration)
        let estimatedFrames = Int(round(fps * duration.seconds))
        let desiredFrames = min(estimatedFrames, maxFrames)
        let finalFrameCount = max(desiredFrames, 1)

        let sampledTimeValues = MLXArray.linspace(
            0, duration.value, count: Int(finalFrameCount)
        ).asArray(Int64.self)

        let timescale = duration.timescale
        let sampledTimes = sampledTimeValues.map { CMTime(value: $0, timescale: timescale) }

        var ciImages: [CIImage] = []
        var timestamps: [CMTime] = []

        for await result in generator.images(for: sampledTimes) {
            switch result {
            case .success(requestedTime: _, let image, actualTime: let actual):
                let ciImage = CIImage(
                    cgImage: image, options: [.colorSpace: CGColorSpace(name: CGColorSpace.sRGB)!])
                let frame = try frameProcessing(.init(frame: ciImage, timeStamp: actual))
                ciImages.append(frame.frame)
                timestamps.append(frame.timeStamp)
            case .failure:
                break
            }
        }

        let framesAsArrays = ciImages.map { MediaProcessing.asMLXArray($0) }
        return ProcessedFrames(
            frames: framesAsArrays,
            timestamps: timestamps,
            totalDuration: duration
        )
    }

    private static func _asProcessedSequence(
        _ videoFrames: [VideoFrame],
        targetFPS: (CMTime) -> Double,
        frameProcessing: (VideoFrame) throws -> VideoFrame = { $0 }
    ) async throws -> ProcessedFrames {
        precondition(videoFrames.isEmpty == false)

        let startTime = videoFrames.first?.timeStamp ?? .zero
        let endTime = videoFrames.last?.timeStamp ?? .zero
        let timeRange = CMTimeRange(start: startTime, end: endTime)
        let duration = timeRange.duration

        let fps = targetFPS(duration)
        let estimatedFrames = Int(round(fps * duration.seconds))
        let desiredFrames = min(estimatedFrames, videoFrames.count)
        let finalFrameCount = max(desiredFrames, 1)

        let sampledTimeValues = MLXArray.linspace(
            0, duration.value, count: Int(finalFrameCount)
        ).asArray(Int64.self)

        let timescale = duration.timescale
        var ciImages: [CIImage] = []
        var timestamps: [CMTime] = []

        var frameIndex = videoFrames.startIndex
        for value in sampledTimeValues {
            let targetTime = CMTime(value: value, timescale: timescale)
            var targetIndex: Int?
            while frameIndex < videoFrames.endIndex {
                if videoFrames[frameIndex].timeStamp > targetTime {
                    break
                } else {
                    targetIndex = frameIndex
                    frameIndex += 1
                }
            }

            if let targetIndex {
                let videoFrame = videoFrames[targetIndex]
                let frame = try frameProcessing(
                    .init(frame: videoFrame.frame, timeStamp: videoFrame.timeStamp))
                ciImages.append(frame.frame)
                timestamps.append(frame.timeStamp)
            }
        }

        let framesAsArrays = ciImages.map { MediaProcessing.asMLXArray($0) }
        return ProcessedFrames(
            frames: framesAsArrays,
            timestamps: timestamps,
            totalDuration: duration
        )
    }

}
