import Abstractions
import Foundation
@testable import ModelDownloader
import Testing

@Suite("ModelConverter Tests")
struct ModelConverterTests {
    @Test("Convert DiscoveredModel to SendableModel")
    @MainActor
    func testBasicConversion() async throws {
        let converter: ModelConverter = ModelConverter()

        var discovered: DiscoveredModel = DiscoveredModel(
            id: "test-org/test-model",
            name: "test-model",
            author: "test-org",
            downloads: 1_000,
            likes: 50,
            tags: ["text-generation"],
            lastModified: Date(),
            files: [
                ModelFile(path: "model.safetensors", size: 2_000_000_000),
                ModelFile(path: "config.json", size: 1_024)
            ]
        )
        discovered.detectedBackends = [.mlx]

        let sendable: SendableModel = try await converter.toSendableModel(discovered)

        #expect(sendable.location == "test-org/test-model")
        #expect(sendable.backend == SendableModel.Backend.mlx)
        #expect(sendable.modelType == SendableModel.ModelType.language)
        #expect(sendable.ramNeeded > 0)
    }

    @Test("Use preferred backend when available")
    @MainActor
    func testPreferredBackend() async throws {
        let converter: ModelConverter = ModelConverter()

        var discovered: DiscoveredModel = DiscoveredModel(
            id: "test-org/multi-backend",
            name: "multi-backend",
            author: "test-org",
            downloads: 1_000,
            likes: 50,
            tags: [],
            lastModified: Date(),
        )
        discovered.detectedBackends = [.mlx, .gguf, .coreml]

        // Test preferring GGUF
        let sendable: SendableModel = try await converter.toSendableModel(discovered, preferredBackend: .gguf)
        #expect(sendable.backend == SendableModel.Backend.gguf)

        // Test with unavailable backend (should use primary)
        let sendable2: SendableModel = try await converter.toSendableModel(discovered, preferredBackend: .mlx)
        #expect(sendable2.backend == SendableModel.Backend.mlx)
    }

    @Test("Throw error for unsupported model")
    @MainActor
    func testUnsupportedModel() async {
        let converter: ModelConverter = ModelConverter()

        let discovered: DiscoveredModel = DiscoveredModel(
            id: "test-org/unsupported",
            name: "unsupported",
            author: "test-org",
            downloads: 0,
            likes: 0,
            tags: [],
            lastModified: Date(),
        )
        discovered.detectedBackends = [] // No backends detected

        do {
            _ = try await converter.toSendableModel(discovered)
            Issue.record("Expected HuggingFaceError.unsupportedFormat")
        } catch HuggingFaceError.unsupportedFormat {
            // Expected error
        } catch {
            Issue.record("Unexpected error: \(error)")
        }
    }

    @Test("RAM extraction from model card")
    @MainActor
    func testRAMExtraction() async throws {
        let converter: ModelConverter = ModelConverter()

        // Test various RAM specification formats
        let testCases: [(String, Int)] = [
            ("This model requires 8GB RAM", 8 * 1_024 * 1_024 * 1_024),
            ("Memory: 16GB", 16 * 1_024 * 1_024 * 1_024),
            ("| RAM | 32GB |", 32 * 1_024 * 1_024 * 1_024),
            ("4GB memory required", 4 * 1_024 * 1_024 * 1_024),
            ("The model needs 12GB of RAM to run", 12 * 1_024 * 1_024 * 1_024)
        ]

        for (modelCard, expectedRAM) in testCases {
            let discovered: DiscoveredModel = DiscoveredModel(
                id: "test/model",
                name: "model",
                author: "test",
                downloads: 0,
                likes: 0,
                tags: [],
                lastModified: Date(),
                files: [ModelFile(path: "model.bin", size: 1_000_000_000)],
            )
            discovered.modelCard = modelCard
            discovered.detectedBackends = [SendableModel.Backend.mlx]

            let sendable: SendableModel = try await converter.toSendableModel(discovered)
            #expect(sendable.ramNeeded == UInt64(expectedRAM))
        }
    }

    @Test("RAM estimation when not specified")
    @MainActor
    func testRAMEstimation() async throws {
        let converter: ModelConverter = ModelConverter()

        // Model without RAM in card
        let discovered: DiscoveredModel = DiscoveredModel(
            id: "test/model",
            name: "model",
            author: "test",
            downloads: 0,
            likes: 0,
            tags: ["text-generation"],
            lastModified: Date(),
            files: [
                ModelFile(path: "model.safetensors", size: 4_000_000_000),
                ModelFile(path: "config.json", size: 1_024)
            ]
        )
        discovered.modelCard = "This is a great model!" // No RAM info
        discovered.detectedBackends = [SendableModel.Backend.mlx]

        let sendable: SendableModel = try await converter.toSendableModel(discovered)

        // Should estimate based on file size with multiplier
        // 4GB * 1.2 = 4.8GB, rounded up to 5GB
        let expectedRAM: Int64 = Int64(5) * 1_024 * 1_024 * 1_024
        #expect(sendable.ramNeeded == expectedRAM)
    }

    @Test("Quantized model RAM estimation")
    @MainActor
    func testQuantizedModelEstimation() async throws {
        let converter: ModelConverter = ModelConverter()

        let discovered: DiscoveredModel = DiscoveredModel(
            id: "test/model-q4",
            name: "model-q4",
            author: "test",
            downloads: 0,
            likes: 0,
            tags: ["text-generation"],
            lastModified: Date(),
            files: [
                ModelFile(path: "model-q4_k_m.gguf", size: 4_000_000_000)
            ]
        )
        discovered.detectedBackends = [SendableModel.Backend.gguf]

        let sendable: SendableModel = try await converter.toSendableModel(discovered)

        // Quantized models use less RAM
        // 4GB * 1.2 * 0.8 = 3.84GB, rounded up to 4GB
        let expectedRAM: Int64 = Int64(4) * 1_024 * 1_024 * 1_024
        #expect(sendable.ramNeeded == expectedRAM)
    }

    @Test("Model type specific RAM multipliers")
    @MainActor
    func testModelTypeRAMMultipliers() async throws {
        let converter: ModelConverter = ModelConverter()

        // Diffusion model - higher multiplier
        let diffusionModel: DiscoveredModel = DiscoveredModel(
            id: "test/sd-model",
            name: "sd-model",
            author: "test",
            downloads: 0,
            likes: 0,
            tags: ["stable-diffusion"],
            lastModified: Date(),
            files: [
                ModelFile(path: "model.safetensors", size: 2_000_000_000)
            ]
        )
        diffusionModel.detectedBackends = [SendableModel.Backend.mlx]

        let diffusionSendable: SendableModel = try await converter.toSendableModel(diffusionModel)

        // 2GB * 1.5 = 3GB
        let expectedDiffusionRAM: Int64 = Int64(3) * 1_024 * 1_024 * 1_024
        #expect(diffusionSendable.ramNeeded == expectedDiffusionRAM)
    }

    @Test("Convert to ModelInfo preview")
    @MainActor
    func testModelInfoConversion() async {
        let converter: ModelConverter = ModelConverter()

        let discovered: DiscoveredModel = DiscoveredModel(
            id: "test-org/test-model",
            name: "test-model",
            author: "test-org",
            downloads: 1_500,
            likes: 75,
            tags: ["llama", "instruct"],
            lastModified: Date(timeIntervalSince1970: 1_700_000_000),
            files: [
                ModelFile(path: "model.bin", size: 1_000_000_000)
            ]
        )
        discovered.detectedBackends = [SendableModel.Backend.mlx]

        let modelInfo: ModelInfo = await converter.toModelInfo(discovered)

        #expect(modelInfo.name == "test-model")
        #expect(modelInfo.backend == SendableModel.Backend.mlx)
        #expect(modelInfo.totalSize == 1_000_000_000)
        #expect(modelInfo.metadata["author"] == "test-org")
        #expect(modelInfo.metadata["downloads"] == "1500")
        #expect(modelInfo.metadata["likes"] == "75")
        #expect(modelInfo.metadata["tags"] == "llama,instruct")
    }
}
