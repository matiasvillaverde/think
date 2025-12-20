import Abstractions
@preconcurrency import CoreGraphics
import Foundation
import Testing

@testable import ImageGenerator

/// Basic tests for ImageGenerator functionality
@Suite("ImageGenerator Basic Tests")
internal struct ImageGeneratorBasicTests {
    @Test("Can create ImageGenerator instance")
    func testCreateImageGenerator() {
        let mockDownloader = MockModelDownloader()
        let generator = ImageGenerator(modelDownloader: mockDownloader)
        // Simple test to ensure we can create an instance
        // The generator is non-optional so it always exists
        _ = generator // Verify it compiles
    }
}
