import Abstractions
import Foundation
@testable import ModelDownloader
import Testing

@Suite("ModelIdentityService Tests")
struct ModelIdentityServiceTests {
    @Test("Generates consistent UUID for model location")
    func testGeneratesConsistentUUID() async {
        // Given
        let service: ModelIdentityService = ModelIdentityService()
        let location: String = "mlx-community/Llama-3.2-3B-Instruct-4bit"

        // When - Generate UUID multiple times
        let uuid1: UUID = await service.generateModelId(for: location)
        let uuid2: UUID = await service.generateModelId(for: location)
        let uuid3: UUID = await service.generateModelId(for: location)

        // Then - All UUIDs should be identical
        #expect(uuid1 == uuid2)
        #expect(uuid2 == uuid3)
    }

    @Test("Generates different UUIDs for different locations")
    func testGeneratesDifferentUUIDs() async {
        // Given
        let service: ModelIdentityService = ModelIdentityService()
        let location1: String = "mlx-community/Llama-3.2-3B-Instruct-4bit"
        let location2: String = "mlx-community/gemma-2-9b-it-4bit"

        // When
        let uuid1: UUID = await service.generateModelId(for: location1)
        let uuid2: UUID = await service.generateModelId(for: location2)

        // Then
        #expect(uuid1 != uuid2)
    }

    @Test("Normalizes model location")
    func testNormalizesModelLocation() async {
        // Given
        let service: ModelIdentityService = ModelIdentityService()

        // Test cases with different formats
        let testCases: [(String, String)] = [
            ("MLX-Community/Llama-3.2-3B", "mlx-community/llama-3.2-3b"),
            ("  mlx-community/model  ", "mlx-community/model"),
            ("AUTHOR/MODEL-NAME", "author/model-name"),
            ("https://huggingface.co/mlx-community/model", "mlx-community/model"),
            ("huggingface.co/mlx-community/model", "mlx-community/model")
        ]

        for (input, expected) in testCases {
            let normalized: String = await service.normalizeLocation(input)
            #expect(normalized == expected)
        }
    }

    @Test("Extracts author and name from location")
    func testExtractsAuthorAndName() async {
        // Given
        let service: ModelIdentityService = ModelIdentityService()

        // Test various location formats
        let testCases: [(String, (String, String))] = [
            ("mlx-community/Llama-3.2-3B", ("mlx-community", "Llama-3.2-3B")),
            ("author/model", ("author", "model")),
            ("https://huggingface.co/test/model-name", ("test", "model-name"))
        ]

        for (location, expected) in testCases {
            let (author, name): (String?, String?) = await service.extractComponents(from: location)
            #expect(author == expected.0)
            #expect(name == expected.1)
        }
    }

    @Test("Handles invalid locations")
    func testHandlesInvalidLocations() async {
        // Given
        let service: ModelIdentityService = ModelIdentityService()

        // Invalid formats should return nil components
        let invalidLocations: [String] = [
            "just-a-name",
            "",
            "/",
            "author/",
            "/model"
        ]

        for location: String in invalidLocations {
            let (author, name): (String?, String?) = await service.extractComponents(from: location)
            #expect(author == nil || name == nil)
        }
    }

    @Test("Creates SendableModel with correct identity")
    func testCreatesSendableModel() async {
        // Given
        let service: ModelIdentityService = ModelIdentityService()
        let location: String = "mlx-community/Llama-3.2-3B-Instruct-4bit"

        // When
        let model: SendableModel = await service.createSendableModel(
            location: location,
            backend: SendableModel.Backend.mlx,
            modelType: .language,
            ramNeeded: 4_294_967_296
        )

        // Then
        #expect(model.location == location)
        #expect(model.backend == SendableModel.Backend.mlx)
        #expect(model.modelType == .language)
        #expect(model.ramNeeded == 4_294_967_296)

        // ID should be deterministic
        let expectedId: UUID = await service.generateModelId(for: location)
        #expect(model.id == expectedId)
    }

    @Test("Resolves model identity from DiscoveredModel")
    @MainActor
    func testResolvesFromDiscoveredModel() async {
        // Given
        let service: ModelIdentityService = ModelIdentityService()
        let discovered: DiscoveredModel = DiscoveredModel(
            id: "mlx-community/Llama-3.2-3B-Instruct-4bit",
            name: "Llama-3.2-3B-Instruct-4bit",
            author: "mlx-community",
            downloads: 10_000,
            likes: 500,
            tags: ["text-generation"],
            lastModified: Date(),
            files: []
        )

        // When
        let identity: ModelIdentity = await service.resolveIdentity(from: discovered)

        // Then
        #expect(identity.location == "mlx-community/Llama-3.2-3B-Instruct-4bit")
        #expect(identity.author == "mlx-community")
        #expect(identity.name == "Llama-3.2-3B-Instruct-4bit")

        // ID should match what would be generated for the location
        let expectedId: UUID = await service.generateModelId(for: identity.location)
        #expect(identity.id == expectedId)
    }

    @Test("Validates model location format")
    func testValidatesModelLocation() async {
        // Given
        let service: ModelIdentityService = ModelIdentityService()

        // Valid formats
        let validLocations: [String] = [
            "author/model",
            "mlx-community/Llama-3.2-3B",
            "test-org/test-model-v2"
        ]

        for location: String in validLocations {
            #expect(await service.isValidLocation(location) == true)
        }

        // Invalid formats
        let invalidLocations: [String] = [
            "",
            "just-a-name",
            "/model",
            "author/",
            "author//model",
            "author model"
        ]

        for location: String in invalidLocations {
            #expect(await service.isValidLocation(location) == false)
        }
    }

    @Test("Caches generated UUIDs for performance")
    func testCachesGeneratedUUIDs() async {
        // Given
        let service: ModelIdentityService = ModelIdentityService()
        let location: String = "mlx-community/test-model"

        // When - Generate UUID many times
        let startTime: Date = Date()
        for _: Int in 0..<1_000 {
            _ = await service.generateModelId(for: location)
        }
        let duration: TimeInterval = Date().timeIntervalSince(startTime)

        // Then - Should be very fast due to caching
        #expect(duration < 0.1) // Should complete in less than 100ms
    }
}
