@testable import Abstractions
import Foundation
@testable import ModelDownloader
import Testing

extension APITests {
    @Test("Same model location produces same UUID")
    @MainActor
    func testDeterministicUUIDGeneration() async throws {
        // Given: Two identical DiscoveredModel instances with the same ID
        let modelId: String = "mlx-community/Llama-3.2-3B-Instruct-4bit"

        let discoveredModel1: DiscoveredModel = DiscoveredModel(
            id: modelId,
            name: "Llama-3.2-3B-Instruct-4bit",
            author: "mlx-community",
            downloads: 1_000,
            likes: 50,
            tags: ["text-generation"],
            lastModified: Date(),
            files: [
                ModelFile(
                    path: "model.safetensors",
                    size: 1_000_000_000
                )
            ]
        )

        // Enrich with detected backends
        await discoveredModel1.enrich(with: EnrichedModelDetails(
            detectedBackends: [.mlx]
        ))

        let discoveredModel2: DiscoveredModel = DiscoveredModel(
            id: modelId,
            name: "Llama-3.2-3B-Instruct-4bit",
            author: "mlx-community",
            downloads: 2_000, // Different metadata
            likes: 100, // Different metadata
            tags: ["text-generation", "llama"], // Different metadata
            lastModified: Date(),
            files: [
                ModelFile(
                    path: "model.safetensors",
                    size: 1_000_000_000
                )
            ]
        )

        // Enrich with detected backends
        await discoveredModel2.enrich(with: EnrichedModelDetails(
            detectedBackends: [.mlx]
        ))

        // When: Converting both to SendableModel
        let converter: ModelConverter = ModelConverter()
        let sendableModel1: SendableModel = try await converter.toSendableModel(discoveredModel1)
        let sendableModel2: SendableModel = try await converter.toSendableModel(discoveredModel2)

        // Then: Both should have the same UUID
        #expect(sendableModel1.id == sendableModel2.id)
        #expect(sendableModel1.location == sendableModel2.location)
        #expect(sendableModel1.location == modelId)
    }

    @Test("Different model locations produce different UUIDs")
    @MainActor
    func testDifferentLocationsDifferentUUIDs() async throws {
        // Given: Two different DiscoveredModel instances
        let discoveredModel1: DiscoveredModel = DiscoveredModel(
            id: "mlx-community/Llama-3.2-3B-Instruct-4bit",
            name: "Llama-3.2-3B-Instruct-4bit",
            author: "mlx-community",
            downloads: 1_000,
            likes: 50,
            tags: ["text-generation"],
            lastModified: Date(),
            files: [
                ModelFile(
                    path: "model.safetensors",
                    size: 1_000_000_000
                )
            ]
        )

        await discoveredModel1.enrich(with: EnrichedModelDetails(
            detectedBackends: [.mlx]
        ))

        let discoveredModel2: DiscoveredModel = DiscoveredModel(
            id: "mlx-community/Mistral-7B-Instruct-v0.2",
            name: "Mistral-7B-Instruct-v0.2",
            author: "mlx-community",
            downloads: 2_000,
            likes: 100,
            tags: ["text-generation"],
            lastModified: Date(),
            files: [
                ModelFile(
                    path: "model.safetensors",
                    size: 7_000_000_000
                )
            ]
        )

        await discoveredModel2.enrich(with: EnrichedModelDetails(
            detectedBackends: [.mlx]
        ))

        // When: Converting both to SendableModel
        let converter: ModelConverter = ModelConverter()
        let sendableModel1: SendableModel = try await converter.toSendableModel(discoveredModel1)
        let sendableModel2: SendableModel = try await converter.toSendableModel(discoveredModel2)

        // Then: They should have different UUIDs
        #expect(sendableModel1.id != sendableModel2.id)
        #expect(sendableModel1.location != sendableModel2.location)
    }

    @Test("UUID is consistent across multiple conversions")
    @MainActor
    func testUUIDConsistencyAcrossConversions() async throws {
        // Given: A DiscoveredModel
        let modelId: String = "mlx-community/phi-3-mini-4k-instruct"
        let discoveredModel: DiscoveredModel = DiscoveredModel(
            id: modelId,
            name: "phi-3-mini-4k-instruct",
            author: "mlx-community",
            downloads: 500,
            likes: 25,
            tags: ["text-generation"],
            lastModified: Date(),
            files: [
                ModelFile(
                    path: "model.safetensors",
                    size: 3_800_000_000
                )
            ]
        )

        await discoveredModel.enrich(with: EnrichedModelDetails(
            detectedBackends: [.mlx]
        ))

        // When: Converting multiple times
        let converter: ModelConverter = ModelConverter()
        var uuids: Set<UUID> = []

        for _ in 0..<10 {
            let sendableModel: SendableModel = try await converter.toSendableModel(discoveredModel)
            uuids.insert(sendableModel.id)
        }

        // Then: All UUIDs should be the same
        #expect(uuids.count == 1)
    }
}
