import Testing
import Foundation
import SwiftData
import Abstractions
@testable import Database
import AbstractionsTestUtilities

@Suite("Model Commands Discovery Tests", .tags(.acceptance))
struct ModelCommandsDiscoveryTests {
    @Test("Create model from DiscoveredModel successfully")
    @MainActor
    func createFromDiscoveredModelSuccess() async throws {
        // Given: A discovered model with rich metadata
        let discoveredModel = DiscoveredModel(
            id: "mlx-community/test-model",
            name: "test-model",
            author: "mlx-community",
            downloads: 1000,
            likes: 50,
            tags: ["text-generation", "mlx", "test"],
            lastModified: Date(timeIntervalSince1970: 1_700_000_000),
            files: [
                Abstractions.ModelFile(
                    path: "model.safetensors",
                    size: 8_000_000_000
                ),
                Abstractions.ModelFile(
                    path: "tokenizer.json",
                    size: 1_000_000
                )
            ],
            license: "apache-2.0",
            licenseUrl: "https://www.apache.org/licenses/LICENSE-2.0"
        )

        // Enrich the discovered model with model card content
        let enrichedDetails = EnrichedModelDetails(
            modelCard: "# Test Model\n\nThis is a test model for validation.",
            cardData: nil,
            imageUrls: [],
            detectedBackends: [.mlx]
        )
        discoveredModel.enrich(with: enrichedDetails)

        let sendableModel = SendableModel(
            id: UUID(),
            ramNeeded: 8_000_000_000,
            modelType: .language,
            location: "mlx-community/test-model",
            architecture: .llama,
            backend: .mlx
        )

        let database = try await ModelCommandsTests.setupTestDatabase()

        // When: Creating model from discovery
        let modelId = try await database.write(
            ModelCommands.CreateFromDiscovery(
                discoveredModel: discoveredModel,
                sendableModel: sendableModel
            )
        )

        // Then: Model should be created with all metadata
        let descriptor = FetchDescriptor<Model>(
            predicate: #Predicate<Model> { $0.id == modelId }
        )
        let models: [Model] = try database.modelContainer.mainContext.fetch(descriptor)
        #expect(models.count == 1)

        let model = models[0]
        #expect(model.id == sendableModel.id)
        #expect(model.name == "test-model")
        #expect(model.displayName == "test-model")
        #expect(model.author == "mlx-community")
        #expect(model.license == "apache-2.0")
        #expect(model.licenseUrl == "https://www.apache.org/licenses/LICENSE-2.0")
        #expect(model.tags.map(\.name).sorted() == ["mlx", "test", "text-generation"])
        #expect(model.downloads == 1000)
        #expect(model.likes == 50)
        #expect(model.lastModified == Date(timeIntervalSince1970: 1_700_000_000))
        #expect(model.type == SendableModel.ModelType.language)
        #expect(model.backend == SendableModel.Backend.mlx)
        #expect(model.ramNeeded == 8_000_000_000)
        #expect(model.state == Model.State.downloadingActive)
        #expect(model.downloadProgress == 0.0)

        // Verify ModelFile entities were created
        #expect(model.files.count == 2)
        let modelFile = model.files.first { $0.name == "model.safetensors" }
        #expect(modelFile != nil)
        #expect(modelFile?.size == 8_000_000_000)

        let tokenizerFile = model.files.first { $0.name == "tokenizer.json" }
        #expect(tokenizerFile != nil)
        #expect(tokenizerFile?.size == 1_000_000)

        // Verify ModelDetails entity was created
        #expect(model.details != nil)
        #expect(model.details?.modelCard == "# Test Model\n\nThis is a test model for validation.")
    }

    @Test("Create model from DiscoveredModel without optional fields")
    @MainActor
    func createFromDiscoveredModelMinimal() async throws {
        // Given: A minimal discovered model
        let discoveredModel = DiscoveredModel(
            id: "test/minimal-model",
            name: "minimal-model",
            author: "test",
            downloads: 0,
            likes: 0,
            tags: [],
            lastModified: Date(),
            files: [
                Abstractions.ModelFile(
                    path: "minimal.safetensors",
                    size: 1_000_000_000
                )
            ]
        )

        let sendableModel = SendableModel(
            id: UUID(),
            ramNeeded: 4_000_000_000,
            modelType: .language,
            location: "test/minimal-model",
            architecture: .unknown,
            backend: .mlx
        )

        let database = try await ModelCommandsTests.setupTestDatabase()

        // When: Creating minimal model from discovery
        let modelId = try await database.write(
            ModelCommands.CreateFromDiscovery(
                discoveredModel: discoveredModel,
                sendableModel: sendableModel
            )
        )

        // Then: Model should be created with defaults for optional fields
        let descriptor = FetchDescriptor<Model>(
            predicate: #Predicate<Model> { $0.id == modelId }
        )
        let models: [Model] = try database.modelContainer.mainContext.fetch(descriptor)
        #expect(models.count == 1)

        let model = models[0]
        #expect(model.name == "minimal-model")
        #expect(model.author == "test")
        #expect(model.license == nil)
        #expect(model.licenseUrl == nil)
        #expect(model.tags.isEmpty)
        #expect(model.downloads == 0)
        #expect(model.likes == 0)
        #expect(model.files.count == 1)
        #expect(model.files[0].name == "minimal.safetensors")
        #expect(model.details == nil)
    }

    @Test("Update existing model from DiscoveredModel")
    @MainActor
    func updateExistingModelFromDiscovery() async throws {
        // Given: An existing model
        let modelId = UUID()
        let originalDTO = ModelDTO(
            type: .language,
            backend: .mlx,
            name: "existing-model",
            displayName: "Existing Model",
            displayDescription: "Original description",
            author: "original-author",
            tags: ["old-tag"],
            downloads: 100,
            likes: 10,
            lastModified: Date(timeIntervalSince1970: 1_600_000_000),
            skills: [],
            parameters: 0,
            ramNeeded: 4_000_000_000,
            size: 0,
            locationHuggingface: "existing-model",
            version: 2,
            architecture: .unknown
        )

        let database = try await ModelCommandsTests.setupTestDatabase()
        try await database.write(ModelCommands.AddModels(models: [originalDTO]))

        // Update the model ID to match our test
        let context = database.modelContainer.mainContext
        let descriptor = FetchDescriptor<Model>()
        let models = try context.fetch(descriptor)
        models[0].id = modelId

        // Updated discovered model data
        let updatedDiscoveredModel = DiscoveredModel(
            id: "existing-model",
            name: "existing-model",
            author: "updated-author",
            downloads: 2000,
            likes: 100,
            tags: ["new-tag", "updated"],
            lastModified: Date(timeIntervalSince1970: 1_700_000_000),
            files: [
                Abstractions.ModelFile(
                    path: "updated-model.safetensors",
                    size: 10_000_000_000
                )
            ],
            license: "mit",
            licenseUrl: "https://opensource.org/licenses/MIT"
        )

        // Enrich the updated discovered model with model card content
        let updatedEnrichedDetails = EnrichedModelDetails(
            modelCard: "Updated model card",
            cardData: nil,
            imageUrls: [],
            detectedBackends: [.mlx]
        )
        updatedDiscoveredModel.enrich(with: updatedEnrichedDetails)

        let sendableModel = SendableModel(
            id: modelId,
            ramNeeded: 8_000_000_000,
            modelType: .language,
            location: "existing-model",
            architecture: .llama,
            backend: .mlx
        )

        // When: Updating model from discovery
        let returnedId = try await database.write(
            ModelCommands.CreateFromDiscovery(
                discoveredModel: updatedDiscoveredModel,
                sendableModel: sendableModel
            )
        )

        // Then: Model should be updated with new metadata
        #expect(returnedId == modelId)

        let updatedDescriptor = FetchDescriptor<Model>(
            predicate: #Predicate<Model> { $0.id == modelId }
        )
        let updatedModels: [Model] = try context.fetch(updatedDescriptor)
        #expect(updatedModels.count == 1)

        let updatedModel = updatedModels[0]
        #expect(updatedModel.author == "updated-author")
        #expect(updatedModel.license == "mit")
        #expect(updatedModel.licenseUrl == "https://opensource.org/licenses/MIT")
        #expect(updatedModel.tags.map(\.name).sorted() == ["new-tag", "updated"])
        #expect(updatedModel.downloads == 2000)
        #expect(updatedModel.likes == 100)
        #expect(updatedModel.lastModified == Date(timeIntervalSince1970: 1_700_000_000))
        #expect(updatedModel.ramNeeded == 8_000_000_000)

        // Verify ModelFile entities were updated
        #expect(updatedModel.files.count == 1)
        #expect(updatedModel.files[0].name == "updated-model.safetensors")
        #expect(updatedModel.files[0].size == 10_000_000_000)

        // Verify ModelDetails was updated
        #expect(updatedModel.details?.modelCard == "Updated model card")
    }

    @Test("CreateFromDiscovery validates required fields")
    @MainActor
    func createFromDiscoveryValidatesRequiredFields() async throws {
        let database = try await ModelCommandsTests.setupTestDatabase()

        // Test with empty name
        let invalidDiscoveredModel = DiscoveredModel(
            id: "test/invalid",
            name: "",
            author: "test",
            downloads: 0,
            likes: 0,
            tags: [],
            lastModified: Date()
        )

        let sendableModel = SendableModel(
            id: UUID(),
            ramNeeded: 4_000_000_000,
            modelType: .language,
            location: "test/invalid",
            architecture: .unknown,
            backend: .mlx
        )

        // When/Then: Should throw validation error
        await #expect(throws: DatabaseError.self) {
            try await database.write(
                ModelCommands.CreateFromDiscovery(
                    discoveredModel: invalidDiscoveredModel,
                    sendableModel: sendableModel
                )
            )
        }
    }

    @Test("CreateFromDiscovery accepts CoreML ZIP files as valid model files")
    @MainActor
    func testCreateFromDiscoveryAcceptsCoreMLZipFiles() async throws {
        // Given
        let database = try await ModelCommandsTests.setupTestDatabase()

        let discoveredModel = DiscoveredModel(
            id: "test-author/test-coreml-model",
            name: "test-coreml-model",
            author: "test-author",
            downloads: 100,
            likes: 10,
            tags: ["coreml", "stable-diffusion"],
            lastModified: Date(),
            files: [
                Abstractions.ModelFile(
                    path: "split-einsum/model.zip",
                    size: 1000000
                )
            ]
        )

        let sendableModel = SendableModel(
            id: UUID(),
            ramNeeded: 8_000_000_000,
            modelType: .diffusion,
            location: "test-author/test-coreml-model",
            architecture: .unknown,
            backend: .coreml
        )

        // When: Create model from discovery
        let modelId = try await database.write(
            ModelCommands.CreateFromDiscovery(
                discoveredModel: discoveredModel,
                sendableModel: sendableModel
            )
        )

        // Then: Model should be created successfully
        let model = try await database.read(
            ModelCommands.GetModelFromId(id: modelId)
        )

        #expect(model.id == modelId)
        #expect(model.name == "test-coreml-model")
        #expect(model.backend == SendableModel.Backend.coreml)
        #expect(model.files.count == 1)
        #expect(model.files.first?.name == "model.zip")
    }

    @Test("CreateFromDiscovery still rejects CoreML models with no files")
    @MainActor
    func testCreateFromDiscoveryRejectsEmptyCoreMLModels() async throws {
        // Given
        let database = try await ModelCommandsTests.setupTestDatabase()

        let discoveredModel = DiscoveredModel(
            id: "test-author/empty-model",
            name: "empty-model",
            author: "test-author",
            downloads: 0,
            likes: 0,
            tags: [],
            lastModified: Date()
        )
        // No files added

        let sendableModel = SendableModel(
            id: UUID(),
            ramNeeded: 8_000_000_000,
            modelType: .diffusion,
            location: "test-author/empty-model",
            architecture: .unknown,
            backend: .coreml
        )

        // When/Then: Should throw validation error
        await #expect(throws: DatabaseError.self) {
            try await database.write(
                ModelCommands.CreateFromDiscovery(
                    discoveredModel: discoveredModel,
                    sendableModel: sendableModel
                )
            )
        }
    }

    @Test("CreateFromDiscovery rejects CoreML models with only config files")
    @MainActor
    func testCreateFromDiscoveryRejectsCoreMLModelsWithOnlyConfigFiles() async throws {
        // Given
        let database = try await ModelCommandsTests.setupTestDatabase()

        let discoveredModel = DiscoveredModel(
            id: "test-author/config-only-model",
            name: "config-only-model",
            author: "test-author",
            downloads: 0,
            likes: 0,
            tags: [],
            lastModified: Date(),
            files: [
                Abstractions.ModelFile(path: "config.json", size: 1000),
                Abstractions.ModelFile(path: "tokenizer.json", size: 2000)
            ]
        )

        let sendableModel = SendableModel(
            id: UUID(),
            ramNeeded: 8_000_000_000,
            modelType: .diffusion,
            location: "test-author/config-only-model",
            architecture: .unknown,
            backend: .coreml
        )

        // When/Then: Should throw validation error
        await #expect(throws: DatabaseError.self) {
            try await database.write(
                ModelCommands.CreateFromDiscovery(
                    discoveredModel: discoveredModel,
                    sendableModel: sendableModel
                )
            )
        }
    }
}
