import Testing
@testable import Abstractions
import Foundation

@Suite("DiscoveredModel Image Tests")
struct DiscoveredModelImageTests {
    @Test("DiscoveredModel initialization with image URLs")
    @MainActor
    func testInitializationWithImageUrls() {
        let imageUrls = [
            "https://huggingface.co/test/model/resolve/main/architecture.png",
            "https://huggingface.co/test/model/resolve/main/sample.jpg"
        ]

        let model = DiscoveredModel(
            id: "test-org/test-model",
            name: "test-model",
            author: "test-org",
            downloads: 1000,
            likes: 50,
            tags: ["text-generation"],
            lastModified: Date()
        )

        // Image URLs are set through enrichment, not initialization
        model.enrich(with: EnrichedModelDetails(
            modelCard: nil,
            cardData: nil,
            imageUrls: imageUrls,
            detectedBackends: []
        ))

        #expect(model.imageUrls == imageUrls)
        #expect(model.hasImages == true)
        #expect(model.imageCount == 2)
    }

    @Test("DiscoveredModel initialization without image URLs")
    @MainActor
    func testInitializationWithoutImageUrls() {
        let model = DiscoveredModel(
            id: "test-org/test-model",
            name: "test-model",
            author: "test-org",
            downloads: 1000,
            likes: 50,
            tags: ["text-generation"],
            lastModified: Date()
        )

        #expect(model.imageUrls.isEmpty)
        #expect(model.hasImages == false)
        #expect(model.imageCount == 0)
    }

    @Test("DiscoveredModel with empty image URLs array")
    @MainActor
    func testInitializationWithEmptyImageUrls() {
        let model = DiscoveredModel(
            id: "test-org/test-model",
            name: "test-model",
            author: "test-org",
            downloads: 1000,
            likes: 50,
            tags: ["text-generation"],
            lastModified: Date()
        )

        // Set empty image URLs through enrichment
        model.enrich(with: EnrichedModelDetails(
            modelCard: nil,
            cardData: nil,
            imageUrls: [],
            detectedBackends: []
        ))

        #expect(model.imageUrls.isEmpty)
        #expect(model.hasImages == false)
        #expect(model.imageCount == 0)
    }

    @Test("DiscoveredModel Equatable conformance with image URLs")
    @MainActor
    func testEquatableConformanceWithImages() {
        let imageUrls = ["https://example.com/image.png"]

        let model1 = DiscoveredModel(
            id: "test-org/test-model",
            name: "test-model",
            author: "test-org",
            downloads: 1000,
            likes: 50,
            tags: ["text-generation"],
            lastModified: Date(timeIntervalSince1970: 0)
        )

        model1.enrich(with: EnrichedModelDetails(
            modelCard: nil,
            cardData: nil,
            imageUrls: imageUrls,
            detectedBackends: []
        ))

        let model2 = DiscoveredModel(
            id: "test-org/test-model",
            name: "test-model",
            author: "test-org",
            downloads: 1000,
            likes: 50,
            tags: ["text-generation"],
            lastModified: Date(timeIntervalSince1970: 0)
        )

        model2.enrich(with: EnrichedModelDetails(
            modelCard: nil,
            cardData: nil,
            imageUrls: imageUrls,
            detectedBackends: []
        ))

        let model3 = DiscoveredModel(
            id: "test-org/test-model",
            name: "test-model",
            author: "test-org",
            downloads: 1000,
            likes: 50,
            tags: ["text-generation"],
            lastModified: Date(timeIntervalSince1970: 0)
        )

        #expect(model1 == model2)
        #expect(model1 == model3) // Equal because they have the same id
    }

    @Test("DiscoveredModel Hashable conformance with image URLs")
    @MainActor
    func testHashableConformanceWithImages() {
        let imageUrls = ["https://example.com/image.png"]

        let model1 = DiscoveredModel(
            id: "test-org/test-model",
            name: "test-model",
            author: "test-org",
            downloads: 1000,
            likes: 50,
            tags: ["text-generation"],
            lastModified: Date(timeIntervalSince1970: 0)
        )

        model1.enrich(with: EnrichedModelDetails(
            modelCard: nil,
            cardData: nil,
            imageUrls: imageUrls,
            detectedBackends: []
        ))

        let model2 = DiscoveredModel(
            id: "test-org/test-model",
            name: "test-model",
            author: "test-org",
            downloads: 1000,
            likes: 50,
            tags: ["text-generation"],
            lastModified: Date(timeIntervalSince1970: 0)
        )

        model2.enrich(with: EnrichedModelDetails(
            modelCard: nil,
            cardData: nil,
            imageUrls: imageUrls,
            detectedBackends: []
        ))

        // Should have same hash
        #expect(model1.hashValue == model2.hashValue)

        // Should be usable in Sets
        let modelSet: Set<DiscoveredModel> = [model1, model2]
        #expect(modelSet.count == 1)
    }

    @Test("Image-related computed properties")
    @MainActor
    func testImageComputedProperties() {
        // Test with multiple images
        let modelWithImages = DiscoveredModel(
            id: "test/model",
            name: "model",
            author: "test",
            downloads: 100,
            likes: 10,
            tags: [],
            lastModified: Date()
        )

        modelWithImages.enrich(with: EnrichedModelDetails(
            modelCard: nil,
            cardData: nil,
            imageUrls: [
                "https://example.com/image1.png",
                "https://example.com/image2.jpg",
                "https://example.com/image3.gif"
            ],
            detectedBackends: []
        ))

        #expect(modelWithImages.hasImages == true)
        #expect(modelWithImages.imageCount == 3)

        // Test with nil images
        let modelWithoutImages = DiscoveredModel(
            id: "test/model",
            name: "model",
            author: "test",
            downloads: 100,
            likes: 10,
            tags: [],
            lastModified: Date()
        )

        #expect(modelWithoutImages.hasImages == false)
        #expect(modelWithoutImages.imageCount == 0)

        // Test with empty array
        let modelWithEmptyImages = DiscoveredModel(
            id: "test/model",
            name: "model",
            author: "test",
            downloads: 100,
            likes: 10,
            tags: [],
            lastModified: Date()
        )

        modelWithEmptyImages.enrich(with: EnrichedModelDetails(
            modelCard: nil,
            cardData: nil,
            imageUrls: [],
            detectedBackends: []
        ))

        #expect(modelWithEmptyImages.hasImages == false)
        #expect(modelWithEmptyImages.imageCount == 0)
    }

    @Test("Image URLs can be mutated after initialization")
    @MainActor
    func testImageUrlsMutation() {
        let model = DiscoveredModel(
            id: "test/model",
            name: "model",
            author: "test",
            downloads: 100,
            likes: 10,
            tags: [],
            lastModified: Date()
        )

        #expect(model.hasImages == false)

        // Simulate lazy population
        model.imageUrls = ["https://example.com/populated.png"]

        #expect(model.hasImages == true)
        #expect(model.imageCount == 1)
    }
}
