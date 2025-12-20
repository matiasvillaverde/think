@testable import AgentOrchestrator
import CoreGraphics
import Foundation
import Testing
#if canImport(UIKit)
import UIKit
#elseif canImport(AppKit)
import AppKit
#endif

@Suite("PlaceholderImageGenerator Tests")
internal struct PlaceholderImageGeneratorTests {
    @Test("Generates non-nil image data with default parameters")
    internal func testGeneratesImageDataWithDefaults() {
        // Given
        let generator: PlaceholderImageGenerator = PlaceholderImageGenerator()

        // When
        let imageData: Data? = generator.generatePlaceholderData()

        // Then
        #expect(imageData != nil, "Should generate image data")
        #expect(imageData?.count ?? 0 > 0, "Generated data should not be empty")
    }

    @Test("Generates image data with custom size")
    internal func testGeneratesImageDataWithCustomSize() {
        // Given
        let customSize: Int = 256
        let generator: PlaceholderImageGenerator = PlaceholderImageGenerator(size: customSize)

        // When
        let imageData: Data? = generator.generatePlaceholderData()

        // Then
        #expect(imageData != nil, "Should generate image data with custom size")
        #expect(imageData?.count ?? 0 > 0, "Generated data should not be empty")
    }

    @Test("Generates image data with custom gradient colors")
    internal func testGeneratesImageDataWithCustomGradient() {
        // Given
        let generator: PlaceholderImageGenerator = PlaceholderImageGenerator(
            size: 128,
            gradientStartRed: 255.0,
            gradientStartGreen: 0.0,
            gradientStartBlue: 0.0,
            gradientEndBlue: 255.0
        )

        // When
        let imageData: Data? = generator.generatePlaceholderData()

        // Then
        #expect(imageData != nil, "Should generate image data with custom gradient")
        #expect(imageData?.count ?? 0 > 0, "Generated data should not be empty")
    }

    @Test("Different configurations produce different data")
    internal func testDifferentConfigurationsProduceDifferentData() {
        // Given
        let generator1: PlaceholderImageGenerator = PlaceholderImageGenerator(
            gradientStartRed: 100.0,
            gradientStartGreen: 100.0
        )
        let generator2: PlaceholderImageGenerator = PlaceholderImageGenerator(
            gradientStartRed: 200.0,
            gradientStartGreen: 200.0
        )

        // When
        let data1: Data? = generator1.generatePlaceholderData()
        let data2: Data? = generator2.generatePlaceholderData()

        // Then
        #expect(data1 != nil, "First generator should produce data")
        #expect(data2 != nil, "Second generator should produce data")
        #expect(data1 != data2, "Different configurations should produce different data")
    }

    @Test("Generates valid image format")
    internal func testGeneratesValidImageFormat() {
        // Given
        let generator: PlaceholderImageGenerator = PlaceholderImageGenerator(size: 64)

        // When
        let imageData: Data? = generator.generatePlaceholderData()

        // Then
        #expect(imageData != nil, "Should generate image data")

        // Verify it's valid image data by attempting to create CGImage
        if let data: Data = imageData {
            #if canImport(UIKit)
            let image: UIImage? = UIImage(data: data)
            #expect(image != nil, "Generated data should be valid UIImage format")
            #elseif canImport(AppKit)
            let image: NSImage? = NSImage(data: data)
            #expect(image != nil, "Generated data should be valid NSImage format")
            #endif
        }
    }

    @Test("Handles edge case sizes")
    internal func testHandlesEdgeCaseSizes() {
        // Given
        let sizes: [Int] = [1, 10, 100, 1_024]

        for size in sizes {
            // When
            let generator: PlaceholderImageGenerator = PlaceholderImageGenerator(size: size)
            let imageData: Data? = generator.generatePlaceholderData()

            // Then
            #expect(
                imageData != nil,
                "Should generate image data for size \(size)"
            )
            #expect(
                imageData?.count ?? 0 > 0,
                "Generated data should not be empty for size \(size)"
            )
        }
    }

    @Test("Generator conforms to PlaceholderImageGenerating protocol")
    internal func testConformsToProtocol() {
        // Given
        let generator: PlaceholderImageGenerating = PlaceholderImageGenerator()

        // When
        let imageData: Data? = generator.generatePlaceholderData()

        // Then
        #expect(imageData != nil, "Should work through protocol interface")
    }

    @Test("Generator is thread-safe as Sendable")
    internal func testIsSendable() async {
        // Given
        let generator: PlaceholderImageGenerator = PlaceholderImageGenerator()

        // When - Execute on different task
        let imageData: Data? = await Task.detached {
            generator.generatePlaceholderData()
        }.value

        // Then
        #expect(imageData != nil, "Should safely generate data across threads")
    }
}
