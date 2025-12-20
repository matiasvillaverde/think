@testable import Abstractions
import Foundation
@testable import ModelDownloader
import Testing

@Suite("ModelConverter Architecture Flow")
struct ModelConverterArchitectureTests {
    let converter: ModelConverter = ModelConverter()

    @Test("Architecture propagation to SendableModel")
    @MainActor
    func testDiscoveredToSendableArchitectureFlow() async throws {
        let discoveredModel: DiscoveredModel = DiscoveredModel(
            id: "meta-llama/Llama-2-7b-chat-hf",
            name: "Llama-2-7b-chat-hf",
            author: "meta-llama",
            downloads: 10_000,
            likes: 500,
            tags: ["text-generation", "conversational"],
            lastModified: Date(),
            files: [
                ModelFile(path: "model.safetensors", size: 7_000_000_000),
                ModelFile(path: "config.json", size: 1_024),
                ModelFile(path: "tokenizer.json", size: 2_048)
            ]
        )
        discoveredModel.detectedBackends = [.mlx]

        let sendableModel: SendableModel = try await converter.toSendableModel(discoveredModel)

        #expect(discoveredModel.inferredArchitecture == .llama)
        #expect(sendableModel.metadata != nil, "Metadata should not be nil")
        #expect(sendableModel.metadata?.architecture == .llama)
    }

    @Test("Metadata creation with architecture")
    @MainActor
    func testMetadataCreationWithArchitecture() async throws {
        let testCases: [(id: String, expectedArch: Architecture)] = [
            ("google/gemma-2-2b-it", .gemma),
            ("mistralai/Mistral-7B-Instruct-v0.2", .mistral),
            ("Qwen/Qwen2.5-7B-Instruct", .qwen),
            ("microsoft/phi-3-mini", .phi),
            ("mlx-community/Phi-3-medium-4k-instruct-4bit", .phi),
            ("mlx-community/Phi-4-mini-instruct-8bit", .phi4)
        ]

        for (id, expectedArch) in testCases {
            let discoveredModel: DiscoveredModel = DiscoveredModel(
                id: id,
                name: id.components(separatedBy: "/").last ?? id,
                author: id.components(separatedBy: "/").first ?? "unknown",
                downloads: 5_000,
                likes: 250,
                tags: ["text-generation"],
                lastModified: Date(),
                files: [
                    ModelFile(path: "model.gguf", size: 4_000_000_000)
                ]
            )
            discoveredModel.detectedBackends = [.gguf]

            let sendableModel: SendableModel = try await converter.toSendableModel(discoveredModel)

            #expect(sendableModel.metadata != nil, "Metadata should exist for \(id)")
            #expect(
                sendableModel.metadata?.architecture == expectedArch,
                "Expected \(expectedArch) for \(id), got \(String(describing: sendableModel.metadata?.architecture))"
            )
        }
    }

    @Test("Unknown architecture handling")
    @MainActor
    func testUnknownArchitectureHandling() async throws {
        let discoveredModel: DiscoveredModel = DiscoveredModel(
            id: "custom-org/experimental-model",
            name: "experimental-model",
            author: "custom-org",
            downloads: 100,
            likes: 5,
            tags: ["experimental"],
            lastModified: Date(),
            files: [
                ModelFile(path: "model.bin", size: 1_000_000_000)
            ]
        )
        discoveredModel.detectedBackends = [.mlx]

        let sendableModel: SendableModel = try await converter.toSendableModel(discoveredModel)

        #expect(sendableModel.metadata != nil)
        #expect(sendableModel.metadata?.architecture == .unknown)
    }

    @Test("Architecture with quantization flow")
    @MainActor
    func testArchitectureWithQuantizationInfo() async throws {
        let discoveredModel: DiscoveredModel = DiscoveredModel(
            id: "TheBloke/Llama-2-7B-GGUF",
            name: "Llama-2-7B-GGUF",
            author: "TheBloke",
            downloads: 50_000,
            likes: 2_500,
            tags: ["llama", "gguf", "quantized"],
            lastModified: Date(),
            files: [
                ModelFile(path: "llama-2-7b.Q4_K_M.gguf", size: 3_800_000_000),
                ModelFile(path: "llama-2-7b.Q8_0.gguf", size: 7_200_000_000)
            ]
        )
        discoveredModel.detectedBackends = [.gguf]

        let sendableModel: SendableModel = try await converter.toSendableModel(discoveredModel)

        #expect(sendableModel.metadata != nil)
        #expect(sendableModel.metadata?.architecture == .llama)
        #expect(sendableModel.backend == .gguf)
    }
}
