import CoreGraphics
import Foundation
@testable import MLXSession
import MLXSessionTestUtilities
import Testing

@Suite("Qwen3 VLM Generation Tests")
struct Qwen3VLMModelTest {
    let baseTest = BaseModelTest()

    @Test("Generate text with Qwen3-VL model and image input")
    func testQwen3VLMGeneration() async throws {
        guard let modelURL: URL = baseTest.getModelURLIfAvailable(
            resourceName: "Qwen3-VL-4B-Instruct-3bit",
            in: Bundle.module
        ) else {
            return
        }

        baseTest.verifyModelFiles(at: modelURL.path)

        let config = ProviderConfiguration(
            location: modelURL,
            authentication: .noAuth,
            modelName: "Qwen3-VL-4B-Instruct-3bit",
            compute: .small
        )

        let session = MLXSessionFactory.create()
        let preloadStream = await session.preload(configuration: config)
        for try await _ in preloadStream {
            // Consume progress updates
        }

        let testImage = try makeTestImage()
        let input = LLMInput(
            context: "Describe the image: <|image_pad|>",
            images: [testImage],
            sampling: SamplingParameters(temperature: 0.2, topP: 0.9, seed: 7),
            limits: ResourceLimits(maxTokens: 40)
        )

        let stream = await session.stream(input)
        let result = try await baseTest.processStream(stream)

        #expect(result.hasReceivedText)
        #expect(!result.text.isEmpty)
        baseTest.verifyMetrics(result.metrics)

        await session.unload()
    }

    private func makeTestImage() throws -> CGImage {
        let width = 64
        let height = 64
        let bytesPerPixel = 4
        let bytesPerRow = width * bytesPerPixel
        var data = [UInt8](repeating: 0, count: width * height * bytesPerPixel)

        for row in 0 ..< height {
            for column in 0 ..< width {
                let offset = (row * width + column) * bytesPerPixel
                data[offset] = UInt8((column * 4) % 255)
                data[offset + 1] = UInt8((row * 4) % 255)
                data[offset + 2] = 128
                data[offset + 3] = 255
            }
        }

        let colorSpace = CGColorSpaceCreateDeviceRGB()
        guard let context = CGContext(
            data: &data,
            width: width,
            height: height,
            bitsPerComponent: 8,
            bytesPerRow: bytesPerRow,
            space: colorSpace,
            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
        ), let image = context.makeImage() else {
            throw VLMError.processing("Failed to create test image.")
        }
        return image
    }
}
