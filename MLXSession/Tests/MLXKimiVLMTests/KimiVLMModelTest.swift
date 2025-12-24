import CoreGraphics
import Foundation
@testable import MLXSession
import MLXSessionTestUtilities
import Testing

@Suite("Kimi VLM Generation Tests")
struct KimiVLMModelTest {
    let baseTest = BaseModelTest()

    @Test("Generate text with Kimi-VL model and image input")
    func testKimiVLMGeneration() async throws {
        guard let modelURL: URL = baseTest.getModelURLIfAvailable(
            resourceName: "Kimi-VL-A3B-Thinking-4bit",
            in: Bundle.module
        ) else {
            return
        }

        baseTest.verifyModelFiles(at: modelURL.path)

        let session = MLXSessionFactory.create()
        let config = makeConfiguration(modelURL: modelURL)
        await preload(session: session, config: config)

        let testImage = try makeTestImage()
        let input = makeInput(testImage: testImage)

        let stream = await session.stream(input)
        let result = try await baseTest.processStream(stream)

        #expect(result.hasReceivedText)
        #expect(!result.text.isEmpty)
        #expect(result.text.lowercased().contains("func "), "Expected Swift code output.")
        baseTest.verifyMetrics(result.metrics)

        await session.unload()
    }

    private func makeConfiguration(modelURL: URL) -> ProviderConfiguration {
        ProviderConfiguration(
            location: modelURL,
            authentication: .noAuth,
            modelName: "Kimi-VL-A3B-Thinking-4bit",
            compute: .small
        )
    }

    private func preload(session: MLXSession, config: ProviderConfiguration) async {
        let preloadStream = await session.preload(configuration: config)
        for try await _ in preloadStream {
            // Consume progress updates
        }
    }

    private func makeInput(testImage: CGImage) -> LLMInput {
        LLMInput(
            context: """
            Provide Swift code only. Declare a function named describeImage that prints \
            a short description of the image: <|media_pad|>
            """,
            images: [testImage],
            sampling: SamplingParameters(temperature: 0.2, topP: 0.9, seed: 7),
            limits: ResourceLimits(maxTokens: 60)
        )
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
