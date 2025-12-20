import Abstractions
import UniformTypeIdentifiers
@preconcurrency import CoreGraphics
import Foundation
import ImageIO
import Testing

@testable import ImageGenerator

/// Acceptance tests for ImageGenerator using real models.
///
/// These tests run the actual ImageGenerator API and verify image generation.
@Suite("ImageGenerator Acceptance Tests")
struct ImageGeneratorAcceptanceTests {
    // MARK: - Properties

    // No stored properties needed - we'll use Bundle.module directly

    // MARK: - Tests

    @Test("Generate deterministic image matching reference")
    func testGeneratesDeterministicImage() async throws {
        guard TestModelAvailability.isAvailable else { return }

        // Given: Specific generation parameters
        let config = ImageConfiguration(
            prompt: "dogs playing",
            steps: 3,
            seed: 42,
            cfgWeight: 7.5
        )

        let generator = try setupGeneratorWithTestModel()
        let model = SendableModel.mock(name: "TestModel")

        // When: Load the model and generate image
        try await loadModel(generator: generator, model: model)
        let (actualImage, metrics) = try await generateImage(
            generator: generator,
            model: model,
            config: config
        )

        // Then: Verify the generated image matches expected
        try verifyGeneratedImage(actualImage, metrics: metrics)

        // Clean up
        try await generator.unload(model: model.id)
    }

    /// Sets up ImageGenerator with test model from bundle
    private func setupGeneratorWithTestModel() throws -> ImageGenerator {
        guard let testModelURL = Bundle.module.url(
            forResource: "TestModel",
            withExtension: nil,
            subdirectory: "Resources"
        ) else {
            throw TestError.resourceNotFound("TestModel")
        }

        let modelDownloader = MockModelDownloader(
            modelExistsResult: true,
            getModelLocationResult: testModelURL
        )
        return ImageGenerator(modelDownloader: modelDownloader)
    }

    /// Loads the model and verifies it completes loading
    private func loadModel(generator: ImageGenerator, model: SendableModel) async throws {
        var loadingCompleted = false
        for try await progress in await generator.load(model: model) where progress.stage == .completed {
            loadingCompleted = true
        }
        #expect(loadingCompleted, "Model should complete loading")
    }

    /// Generates image using the provided configuration
    private func generateImage(
        generator: ImageGenerator,
        model: SendableModel,
        config: ImageConfiguration
    ) async throws -> (CGImage, ImageMetrics?) {
        var generatedImage: CGImage?
        var metrics: ImageMetrics?

        for try await progress in await generator.generate(
            model: model,
            config: config
        ) {
            generatedImage = progress.currentImage
            metrics = progress.imageMetrics
        }

        guard let actualImage = generatedImage else {
            throw TestError.noImageGenerated
        }

        return (actualImage, metrics)
    }

    /// Verifies the generated image matches the expected reference image
    private func verifyGeneratedImage(_ actualImage: CGImage, metrics: ImageMetrics?) throws {
        // Get expected image from bundle
        guard let expectedImageURL = Bundle.module.url(
            forResource: "Resources/dogs_playing_expected",
            withExtension: "png"
        ) else {
            throw TestError.resourceNotFound("dogs_playing_expected.png")
        }

        // Verify dimensions match expected
        let expectedImage = try loadImage(from: expectedImageURL)
        #expect(actualImage.width == expectedImage.width)
        #expect(actualImage.height == expectedImage.height)

         #expect(
             compareImages(actualImage, expectedImage),
             "Generated image should match reference exactly"
         )

        // Verify metrics were provided
        #expect(metrics != nil, "Metrics should be provided")
        if let metrics = metrics {
            // Verify timing metrics
            if let timing = metrics.timing {
                #expect(timing.totalTime > .zero)
                if let modelLoadTime = timing.modelLoadTime {
                    #expect(modelLoadTime > .zero)
                }
            }
            // Verify usage metrics
            if let usage = metrics.usage {
                #expect(usage.modelParameters > 0)
            }
            // Verify generation metrics
            if let generation = metrics.generation {
                #expect(generation.steps > 0)
            }
        }
    }

    private func normalizeImage(_ image: CGImage) -> CGImage? {
        let width = image.width
        let height = image.height
        let colorSpace = CGColorSpaceCreateDeviceRGB()

        // Create a bitmap context with a consistent format (32-bit RGBA)
        guard let context = CGContext(
            data: nil,
            width: width,
            height: height,
            bitsPerComponent: 8,
            bytesPerRow: width * 4,
            space: colorSpace,
            bitmapInfo: CGImageAlphaInfo.noneSkipLast.rawValue
        ) else {
            return nil
        }

        // Draw the image into the normalized context
        context.draw(image, in: CGRect(x: 0, y: 0, width: width, height: height))

        // Create a new image from the context
        return context.makeImage()
    }

    private func compareImages(_ image1: CGImage, _ image2: CGImage) -> Bool {
        // First check dimensions
        guard image1.width == image2.width,
              image1.height == image2.height else {
            return false
        }

        // Normalize both images to the same format
        guard let normalized1 = normalizeImage(image1),
              let normalized2 = normalizeImage(image2) else {
            return false
        }

        // Now compare the normalized images
        guard let data1 = normalized1.dataProvider?.data,
              let data2 = normalized2.dataProvider?.data else {
            return false
        }

        return data1 == data2
    }

    // MARK: - Helper Functions

    private func saveImageAsReference(_ image: CGImage, filename: String) throws {

        // Try to find the Resources directory in the package
        let currentFile = URL(fileURLWithPath: #file)
        let packageRoot = currentFile
            .deletingLastPathComponent() // Remove filename
            .deletingLastPathComponent() // Remove Tests directory (adjust as needed)

        let resourcesDir = packageRoot
            .appendingPathComponent("Tests")
            .appendingPathComponent("ImageGeneratorTests") // Update this if different
            .appendingPathComponent("Resources")

        let resourcesPath = resourcesDir.appendingPathComponent(filename)

        print("Saving reference image to: \(resourcesPath.path)")

        // Create Resources directory if it doesn't exist
        try FileManager.default.createDirectory(
            at: resourcesDir,
            withIntermediateDirectories: true,
            attributes: nil
        )

        // Create CGImageDestination
        guard let destination = CGImageDestinationCreateWithURL(
            resourcesPath as CFURL,
            UTType.png.identifier as CFString,
            1,
            nil
        ) else {
            throw TestError.failedToCreateImageDestination
        }

        // Add image to destination
        CGImageDestinationAddImage(destination, image, nil)

        // Finalize the image write
        guard CGImageDestinationFinalize(destination) else {
            throw TestError.failedToSaveImage
        }
    }

    // Add this function if you don't have it already
    private func loadImage(from url: URL) throws -> CGImage {
        guard let imageSource = CGImageSourceCreateWithURL(url as CFURL, nil),
              let image = CGImageSourceCreateImageAtIndex(imageSource, 0, nil)
        else {
            throw TestError.imageLoadFailed(url.path)
        }
        return image
    }

}

// MARK: - Test Errors

private enum TestError: Error, CustomStringConvertible {
    case resourceNotFound(String)
    case noImageGenerated
    case imageLoadFailed(String)
    case imageConversionFailed
    case failedToCreateImageDestination
    case failedToSaveImage

    var description: String {
        switch self {
        case .resourceNotFound(let resource):
            return "Resource not found: \(resource)"

        case .noImageGenerated:
            return "No image was generated"

        case .imageLoadFailed(let path):
            return "Failed to load image from: \(path)"

        case .imageConversionFailed:
            return "Failed to convert image to PNG data"

        case .failedToCreateImageDestination:
            return "Failed to create image destination"

        case .failedToSaveImage:
            return "Failed to save image"
        }
    }
}
