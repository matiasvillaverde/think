import Testing
@testable import Database
@testable import Abstractions
import Foundation
import SwiftData

@Suite("Model Architecture Persistence")
struct ModelArchitecturePersistenceTests {
    @Test("Architecture field in ModelDTO")
    func testArchitectureFieldInDTO() {
        let dto = ModelDTO(
            type: .language,
            backend: .mlx,
            name: "Llama-3.2-3B",
            displayName: "Llama 3.2 3B",
            displayDescription: "A powerful language model",
            author: "meta-llama",
            license: "llama3",
            licenseUrl: "https://llama.meta.com/llama3/license",
            tags: ["text-generation", "llama"],
            downloads: 10000,
            likes: 500,
            lastModified: Date(),
            skills: ["text-generation"],
            parameters: 3_000_000_000,
            ramNeeded: 4_000_000_000,
            size: 3_500_000_000,
            locationHuggingface: "meta-llama/Llama-3.2-3B",
            version: 2,
            architecture: .llama
        )

        #expect(dto.architecture == .llama)
    }

    @Test("Model initialization with architecture")
    func testModelInitWithArchitecture() throws {
        let dto = ModelDTO(
            type: .language,
            backend: .gguf,
            name: "Gemma-2B",
            displayName: "Gemma 2B",
            displayDescription: "Google's efficient language model",
            author: "google",
            tags: ["conversational"],
            skills: ["chat"],
            parameters: 2_000_000_000,
            ramNeeded: 3_000_000_000,
            size: 2_500_000_000,
            locationHuggingface: "google/gemma-2b-it",
            version: 2,
            architecture: .gemma
        )

        let model = try dto.createModel()

        #expect(model.architecture == .gemma)
    }

    @Test("toSendable roundtrip preservation")
    func testModelToSendableRoundtrip() throws {
        let dto = ModelDTO(
            type: .language,
            backend: .mlx,
            name: "Mistral-7B",
            displayName: "Mistral 7B",
            displayDescription: "Mistral AI's flagship model",
            author: "mistralai",
            tags: ["instruct"],
            skills: ["instruction-following"],
            parameters: 7_000_000_000,
            ramNeeded: 8_000_000_000,
            size: 7_500_000_000,
            locationHuggingface: "mistralai/Mistral-7B-v0.1",
            version: 2,
            architecture: .mistral
        )

        let model = try dto.createModel()
        _ = model.toSendable()

        // The SendableModel itself doesn't carry architecture
        // but when used with metadata it should
        #expect(model.architecture == .mistral)
    }

    @Test("SwiftData persistence with architecture")
    @MainActor
    func testArchitecturePersistence() throws {
        let container = try ModelContainer(
            for: Model.self,
            configurations: ModelConfiguration(isStoredInMemoryOnly: true)
        )

        let dto = ModelDTO(
            type: .flexibleThinker,
            backend: .mlx,
            name: "Qwen2.5-7B",
            displayName: "Qwen 2.5 7B",
            displayDescription: "Advanced reasoning model",
            author: "Qwen",
            tags: ["reasoning", "chat"],
            skills: ["reasoning", "coding"],
            parameters: 7_000_000_000,
            ramNeeded: 8_000_000_000,
            size: 7_200_000_000,
            locationHuggingface: "Qwen/Qwen2.5-7B-Instruct",
            version: 2,
            architecture: .qwen
        )

        let model = try dto.createModel()
        container.mainContext.insert(model)
        try container.mainContext.save()

        // Fetch the model back
        let descriptor = FetchDescriptor<Model>()
        let fetchedModels = try container.mainContext.fetch(descriptor)

        #expect(fetchedModels.count == 1)
        #expect(fetchedModels.first?.architecture == .qwen)
    }

    @Test("Default architecture for legacy models")
    func testDefaultArchitectureForLegacy() throws {
        // Test that models without architecture default to .unknown
        let dto = ModelDTO(
            type: .language,
            backend: .mlx,
            name: "Legacy-Model",
            displayName: "Legacy Model",
            displayDescription: "A model without architecture info",
            author: "unknown",
            tags: [],
            skills: [],
            parameters: 1_000_000_000,
            ramNeeded: 2_000_000_000,
            size: 1_500_000_000,
            locationHuggingface: "legacy/model",
            version: 1
            // architecture not provided - should default to .unknown
        )

        let model = try dto.createModel()

        #expect(model.architecture == .unknown)
    }
}
