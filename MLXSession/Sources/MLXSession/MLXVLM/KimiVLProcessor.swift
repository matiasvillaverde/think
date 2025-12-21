import CoreImage
import Foundation
import MLX
import Tokenizers

internal struct KimiVLProcessor: UserInputProcessor {
    private let config: KimiVLProcessorConfiguration
    private let tokenizer: any Tokenizer

    init(_ config: KimiVLProcessorConfiguration, tokenizer: any Tokenizer) {
        self.config = config
        self.tokenizer = tokenizer
    }

    private var imageMeanTuple: (CGFloat, CGFloat, CGFloat) {
        (
            CGFloat(config.imageMean[safe: 0] ?? 0.5),
            CGFloat(config.imageMean[safe: 1] ?? 0.5),
            CGFloat(config.imageMean[safe: 2] ?? 0.5)
        )
    }

    private var imageStdTuple: (CGFloat, CGFloat, CGFloat) {
        (
            CGFloat(config.imageStd[safe: 0] ?? 0.5),
            CGFloat(config.imageStd[safe: 1] ?? 0.5),
            CGFloat(config.imageStd[safe: 2] ?? 0.5)
        )
    }

    private func rescale(_ image: CIImage, mergeKernelSize: [Int]) throws -> CIImage {
        let patchSize = config.patchSize
        let size = image.extent.integral.size
        var width = Int(size.width)
        var height = Int(size.height)

        let gridW = width / patchSize
        let gridH = height / patchSize
        if gridW * gridH > config.inTokenLimit {
            let scale = sqrt(
                Float(config.inTokenLimit) / Float(gridW * gridH)
            )
            width = Int(Float(width) * scale)
            height = Int(Float(height) * scale)
        }

        var image = MediaProcessing.resampleBicubic(
            image,
            to: CGSize(width: width, height: height)
        )

        let padSizeH = mergeKernelSize[0] * patchSize
        let padSizeW = mergeKernelSize[1] * patchSize

        if config.padInput {
            let padH = (padSizeH - height % padSizeH) % padSizeH
            let padW = (padSizeW - width % padSizeW) % padSizeW
            if padH > 0 || padW > 0 {
                image = MediaProcessing.padToSize(
                    image,
                    size: CGSize(width: width + padW, height: height + padH)
                )
            }
        } else {
            let newW = width - width % padSizeW
            let newH = height - height % padSizeH
            image = MediaProcessing.centerCrop(
                image,
                size: CGSize(width: newW, height: newH)
            )
        }

        let finalSize = image.extent.integral.size
        let finalGridW = Int(finalSize.width) / patchSize
        let finalGridH = Int(finalSize.height) / patchSize
        if finalGridW >= 512 || finalGridH >= 512 {
            throw VLMError.imageProcessingFailure("Exceed pos emb limits.")
        }

        return image
    }

    private func toMLX(_ image: CIImage) -> MLXArray {
        let normalized = MediaProcessing.normalize(
            image,
            mean: imageMeanTuple,
            std: imageStdTuple
        )
        let array = MediaProcessing.asMLXArray(normalized)
        return MLX.squeezed(array, axis: 0)
    }

    private func patchify(_ image: MLXArray) -> (MLXArray, (Int, Int)) {
        let patchSize = config.patchSize
        let channels = image.dim(0)
        let height = image.dim(1)
        let width = image.dim(2)

        var patches = image.reshaped(
            channels,
            height / patchSize,
            patchSize,
            width / patchSize,
            patchSize
        )
        patches = patches.transposed(1, 3, 0, 2, 4)
        patches = patches.reshaped(-1, channels, patchSize, patchSize)

        return (patches, (height / patchSize, width / patchSize))
    }

    private func preprocess(
        images: [CIImage],
        processing: UserInput.Processing?
    ) throws -> (MLXArray, [THW], MLXArray) {
        let mergeKernelSize = config.mergeKernelSize
        var pixelValues = [MLXArray]()
        var frames: [THW] = []
        var gridPairs: [Int] = []

        for image in images {
            let image = MediaProcessing.apply(image, processing: processing)
            let resized = try rescale(image, mergeKernelSize: mergeKernelSize)
            let prepared = toMLX(MediaProcessing.inSRGBToneCurveSpace(resized))
            let (patches, grid) = patchify(prepared)
            pixelValues.append(patches)
            frames.append(THW(1, grid.0, grid.1))
            gridPairs.append(contentsOf: [grid.0, grid.1])
        }

        let concatenatedPixels = concatenated(pixelValues, axis: 0)
        let gridHws = MLXArray(gridPairs).reshaped(images.count, 2)
        return (concatenatedPixels, frames, gridHws)
    }

    private func expandMediaTokens(
        tokens: [Int],
        gridHws: MLXArray,
        tokenId: Int
    ) throws -> [Int] {
        let mergeLength = (config.mergeKernelSize.first ?? 1) * (config.mergeKernelSize.dropFirst().first ?? 1)
        let gridValues = gridHws.asArray(Int.self)
        var grids: [(Int, Int)] = []
        for index in stride(from: 0, to: gridValues.count, by: 2) {
            grids.append((gridValues[index], gridValues[index + 1]))
        }

        var expanded: [Int] = []
        var imageIndex = 0

        for token in tokens {
            if token == tokenId {
                guard imageIndex < grids.count else {
                    throw VLMError.processing("Missing image for media placeholder.")
                }
                let (h, w) = grids[imageIndex]
                let placeholderCount = (h * w) / max(mergeLength, 1)
                expanded.append(contentsOf: Array(repeating: tokenId, count: placeholderCount))
                imageIndex += 1
            } else {
                expanded.append(token)
            }
        }

        if imageIndex != grids.count {
            throw VLMError.processing("Unused image inputs: \(grids.count - imageIndex)")
        }

        return expanded
    }

    func prepare(input: UserInput) async throws -> LMInput {
        if !input.videos.isEmpty {
            throw VLMError.singleMediaTypeAllowed
        }
        let messages = DefaultMessageGenerator().generate(from: input)

        let promptTokens: [Int]
        do {
            promptTokens = try tokenizer.applyChatTemplate(messages: messages)
        } catch {
            let prompt = messages.compactMap { $0["content"] as? String }.joined(separator: "\n\n")
            promptTokens = tokenizer.encode(text: prompt)
        }

        if input.images.isEmpty {
            let promptArray = MLXArray(promptTokens).expandedDimensions(axis: 0)
            return LMInput(text: .init(tokens: promptArray))
        }

        let images = try input.images.map { try $0.asCIImage() }
        let (pixels, frames, gridHws) = try preprocess(images: images, processing: input.processing)

        let mediaTokenId = tokenizer.convertTokenToId("<|media_pad|>")
            ?? tokenizer.encode(text: "<|media_pad|>").first

        guard let mediaTokenId else {
            throw VLMError.processing("Missing <|media_pad|> token in tokenizer vocabulary.")
        }

        let expandedTokens = try expandMediaTokens(
            tokens: promptTokens,
            gridHws: gridHws,
            tokenId: mediaTokenId
        )

        let promptArray = MLXArray(expandedTokens).expandedDimensions(axis: 0)
        let processedImage = LMInput.ProcessedImage(pixels: pixels, frames: frames)

        return LMInput(text: .init(tokens: promptArray), image: processedImage)
    }
}

private extension Array {
    subscript(safe index: Int) -> Element? {
        indices.contains(index) ? self[index] : nil
    }
}
