import Abstractions
import AbstractionsTestUtilities
@testable import AgentOrchestrator
import CoreGraphics
@testable import Database
import Foundation
import Testing
#if canImport(AppKit)
import AppKit
#endif

// MARK: - Image Test Helpers

internal enum ImageTestHelpers {
    private static let kMegabyte: UInt64 = 1_048_576
    private static let kGigabyteMultiplier: UInt64 = 1_024
    private static let kSevenBillion: UInt64 = 7_000_000_000
    private static let kOneBillion: UInt64 = 1_000_000_000
    private static let kEightMultiplier: UInt64 = 8
    private static let kSixMultiplier: UInt64 = 6
    private static let kTwoMultiplier: UInt64 = 2
    private static let kOneMultiplier: UInt64 = 1
    private static let kActiveMemory: UInt64 = 1_000
    private static let kCacheMemory: UInt64 = 500
    private static let kPeakMemory: UInt64 = 1_500
    private static let kModelLoadTime: Double = 2.0
    private static let kPromptTime: Double = 0.5
    private static let kGenerateTime: Double = 10.0
    private static let kPromptTokensPerSecond: Double = 20.0
    private static let kTokensPerSecond: Double = 15.0
    private static let kResponseTokenCount: UInt = 77
    private static let kPromptTokenCount: UInt = 10
    private static let kProgressTenPercent: Double = 0.1
    private static let kProgressTwentyPercent: Double = 0.2
    private static let kProgressFiftyPercent: Double = 0.5
    private static let kProgressHundredPercent: Double = 1.0
    private static let kGenerationSteps: Int = 50
    private static let kGenerationMidStep: Int = 25
    private static let kGenerationFirstStep: Int = 1
    private static let kImageSize: Int = 1
    private static let kBitsPerComponent: Int = 8
    private static let kBytesPerRow: Int = 4
    private static let kRedPixelValue: UInt8 = 255
    private static let kZeroPixelValue: UInt8 = 0
    private static let kAlphaPixelValue: UInt8 = 255

    @MainActor
    internal static func createDatabase() async throws -> Database {
        let config: DatabaseConfiguration = DatabaseConfiguration(
            isStoredInMemoryOnly: true,
            allowsSave: true,
            ragFactory: MockRagFactory(mockRag: MockRagging())
        )
        let database: Database = try Database.new(configuration: config)
        _ = try await database.execute(AppCommands.Initialize())
        return database
    }

    internal static func createImageModelDTO() -> ModelDTO {
        ModelDTO(
            type: .diffusion,
            backend: .coreml,
            name: "stable-diffusion-xl",
            displayName: "Stable Diffusion XL",
            displayDescription: "Image generation model",
            skills: ["image-generation"],
            parameters: kSevenBillion,
            ramNeeded: kEightMultiplier * kMegabyte * kGigabyteMultiplier,
            size: kSixMultiplier * kMegabyte * kGigabyteMultiplier,
            locationHuggingface: "stabilityai/sdxl",
            version: 1,
            architecture: .stableDiffusion
        )
    }

    internal static func createLanguageModelDTO() -> ModelDTO {
        ModelDTO(
            type: .language,
            backend: .mlx,
            name: "test-language-model",
            displayName: "Test Language Model",
            displayDescription: "Language model for testing",
            skills: ["text-generation"],
            parameters: kOneBillion,
            ramNeeded: kTwoMultiplier * kMegabyte * kGigabyteMultiplier,
            size: kOneMultiplier * kMegabyte * kGigabyteMultiplier,
            locationHuggingface: "test/language",
            version: 1,
            architecture: .llama
        )
    }

    internal static func createTestCGImage() -> CGImage? {
        var pixelData: [UInt8] = [
            kRedPixelValue,
            kZeroPixelValue,
            kZeroPixelValue,
            kAlphaPixelValue
        ]
        return createCGImageFromPixelData(&pixelData)
    }

    private static func createCGImageFromPixelData(_ pixelData: inout [UInt8]) -> CGImage? {
        let colorSpace: CGColorSpace = CGColorSpaceCreateDeviceRGB()
        guard let context = CGContext(
            data: &pixelData,
            width: kImageSize,
            height: kImageSize,
            bitsPerComponent: kBitsPerComponent,
            bytesPerRow: kBytesPerRow,
            space: colorSpace,
            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
        ) else {
            return nil
        }
        return context.makeImage()
    }

    private static let kImageWidth: Int = 512
    private static let kImageHeight: Int = 512
    private static let kGuidanceScale: Float = 7.5

    internal static func createTestImageMetrics() -> ImageMetrics {
        let timing: ImageTimingMetrics = createTestTimingMetrics()
        let usage: ImageUsageMetrics = createTestUsageMetrics()
        let generation: ImageGenerationMetrics = createTestGenerationMetrics()

        return ImageMetrics(
            timing: timing,
            usage: usage,
            generation: generation
        )
    }

    private static func createTestTimingMetrics() -> ImageTimingMetrics {
        ImageTimingMetrics(
            totalTime: Duration.seconds(kGenerateTime),
            modelLoadTime: Duration.seconds(kModelLoadTime),
            promptEncodingTime: Duration.seconds(kPromptTime),
            denoisingStepTimes: [],
            vaeDecodingTime: nil,
            postProcessingTime: nil
        )
    }

    private static func createTestUsageMetrics() -> ImageUsageMetrics {
        ImageUsageMetrics(
            activeMemory: kActiveMemory,
            peakMemory: kPeakMemory,
            modelParameters: Int(kSevenBillion),
            promptTokens: Int(kPromptTokenCount),
            negativePromptTokens: nil,
            gpuMemory: nil,
            usedGPU: false
        )
    }

    private static func createTestGenerationMetrics() -> ImageGenerationMetrics {
        ImageGenerationMetrics(
            width: kImageWidth,
            height: kImageHeight,
            steps: kGenerationSteps,
            guidanceScale: kGuidanceScale,
            scheduler: "DPMSolver",
            modelName: "stable-diffusion-xl",
            seed: nil,
            safetyCheckPassed: true,
            batchSize: 1
        )
    }

    internal static func createImageGenerationStages() -> [ImageGenerationProgress] {
        [
            createPreparingStage(),
            createInitialGeneratingStage(),
            createMidGeneratingStage(),
            createCompletedStage()
        ]
    }

    private static func createPreparingStage() -> ImageGenerationProgress {
        ImageGenerationProgress(
            stage: .tokenizingPrompt,
            currentImage: nil,
            progressPercentage: kProgressTenPercent,
            imageMetrics: nil
        )
    }

    private static func createInitialGeneratingStage() -> ImageGenerationProgress {
        ImageGenerationProgress(
            stage: .generating(step: kGenerationFirstStep, totalSteps: kGenerationSteps),
            currentImage: nil,
            progressPercentage: kProgressTwentyPercent,
            imageMetrics: nil
        )
    }

    private static func createMidGeneratingStage() -> ImageGenerationProgress {
        ImageGenerationProgress(
            stage: .generating(step: kGenerationMidStep, totalSteps: kGenerationSteps),
            currentImage: createTestCGImage(),
            progressPercentage: kProgressFiftyPercent,
            imageMetrics: nil
        )
    }

    private static func createCompletedStage() -> ImageGenerationProgress {
        ImageGenerationProgress(
            stage: .completed,
            currentImage: createTestCGImage(),
            progressPercentage: kProgressHundredPercent,
            imageMetrics: createTestImageMetrics()
        )
    }

    internal static func createCGImageFromData(_ data: Data) -> CGImage? {
        #if canImport(AppKit)
        guard let nsImage = NSImage(data: data) else {
            return nil
        }
        return nsImage.cgImage(forProposedRect: nil, context: nil, hints: nil)
        #else
        guard let dataProvider = CGDataProvider(data: data as CFData),
            let cgImage = CGImage(
                jpegDataProviderSource: dataProvider,
                decode: nil,
                shouldInterpolate: true,
                intent: .defaultIntent
            ) else {
            return nil
        }
        return cgImage
        #endif
    }
}
