import Abstractions
import Foundation
@testable import ModelDownloader
import Testing

@Suite("DiscoveredModel Tests")
struct DiscoveredModelTests {
    @Test("DiscoveredModel initialization")
    @MainActor
    func testInitialization() {
        let files: [ModelFile] = [
            ModelFile(path: "model.safetensors", size: 1_000_000_000),
            ModelFile(path: "config.json", size: 1_024)
        ]

        let model: DiscoveredModel = DiscoveredModel(
            id: "test-org/test-model",
            name: "test-model",
            author: "test-org",
            downloads: 1_000,
            likes: 50,
            tags: ["text-generation", "llama"],
            lastModified: Date(),
            files: files,
            license: "MIT",
            licenseUrl: "https://opensource.org/licenses/MIT"
        )
        model.modelCard = "# Test Model"
        model.detectedBackends = [SendableModel.Backend.mlx]

        #expect(model.id == "test-org/test-model")
        #expect(model.name == "test-model")
        #expect(model.author == "test-org")
        #expect(model.downloads == 1_000)
        #expect(model.likes == 50)
        #expect(model.tags == ["text-generation", "llama"])
        #expect(model.modelCard == "# Test Model")
        #expect(model.files == files)
        #expect(model.detectedBackends == [SendableModel.Backend.mlx])
        #expect(model.license == "MIT")
        #expect(model.licenseUrl == "https://opensource.org/licenses/MIT")
    }

    @Test("Total size calculation")
    @MainActor
    func testTotalSize() {
        let files: [ModelFile] = [
            ModelFile(path: "file1", size: 1_000_000),
            ModelFile(path: "file2", size: 2_000_000),
            ModelFile(path: "file3", size: nil), // No size
            ModelFile(path: "file4", size: 3_000_000)
        ]

        let model: DiscoveredModel = DiscoveredModel(
            id: "test/model",
            name: "model",
            author: "test",
            downloads: 0,
            likes: 0,
            tags: [],
            lastModified: Date(),
            files: files
        )

        #expect(model.totalSize == 6_000_000)
        #expect(model.formattedTotalSize.contains("MB"))
    }

    @Test("Backend detection properties")
    @MainActor
    func testBackendDetection() {
        let modelWithBackends: DiscoveredModel = DiscoveredModel(
            id: "test/model",
            name: "model",
            author: "test",
            downloads: 0,
            likes: 0,
            tags: [],
            lastModified: Date(),
            files: []
        )
        modelWithBackends.detectedBackends = [SendableModel.Backend.mlx, SendableModel.Backend.gguf]

        #expect(modelWithBackends.hasDetectedBackends == true)
        #expect(modelWithBackends.primaryBackend == SendableModel.Backend.mlx)

        let modelWithoutBackends: DiscoveredModel = DiscoveredModel(
            id: "test/model",
            name: "model",
            author: "test",
            downloads: 0,
            likes: 0,
            tags: [],
            lastModified: Date(),
            files: []
        )

        #expect(modelWithoutBackends.hasDetectedBackends == false)
        #expect(modelWithoutBackends.primaryBackend == nil)
    }

    @Test("Model type inference from tags")
    @MainActor
    func testInferredModelType() {
        // Diffusion models
        let diffusionModel: DiscoveredModel = createModel(tags: ["stable-diffusion", "text-to-image"])
        #expect(diffusionModel.inferredModelType == .diffusion)

        let diffusionXLModel: DiscoveredModel = createModel(tags: ["stable-diffusion-xl", "xl"])
        #expect(diffusionXLModel.inferredModelType == .diffusionXL)

        // Vision models
        let visionModel: DiscoveredModel = createModel(tags: ["vision", "image-text-to-text"])
        #expect(visionModel.inferredModelType == .visualLanguage)

        let multimodalModel: DiscoveredModel = createModel(tags: ["multimodal", "text-generation"])
        #expect(multimodalModel.inferredModelType == .visualLanguage)

        // Language models
        let languageModel: DiscoveredModel = createModel(tags: ["text-generation", "conversational"])
        #expect(languageModel.inferredModelType == .language)

        // Deep language models (by size)
        let deepModel1: DiscoveredModel = createModel(name: "Llama-70B-Instruct", tags: ["text-generation"])
        #expect(deepModel1.inferredModelType == .deepLanguage)

        let deepModel2: DiscoveredModel = createModel(name: "Falcon-40B", tags: ["language-model"])
        #expect(deepModel2.inferredModelType == .deepLanguage)

        // Flexible thinker
        let qwenModel: DiscoveredModel = createModel(tags: ["qwen", "text-generation"])
        #expect(qwenModel.inferredModelType == .flexibleThinker)

        // Default case
        let unknownModel: DiscoveredModel = createModel(tags: ["unknown-tag"])
        #expect(unknownModel.inferredModelType == .language)
    }

    @Test("Model validation")
    @MainActor
    func testIsValidModel() {
        // Valid model with files and backends
        let validModel: DiscoveredModel = DiscoveredModel(
            id: "test/model",
            name: "model",
            author: "test",
            downloads: 0,
            likes: 0,
            tags: [],
            lastModified: Date(),
            files: [ModelFile(path: "model.bin")]
        )
        validModel.detectedBackends = [SendableModel.Backend.mlx]
        #expect(validModel.isValidModel == true)

        // Invalid - no files
        let noFilesModel: DiscoveredModel = DiscoveredModel(
            id: "test/model",
            name: "model",
            author: "test",
            downloads: 0,
            likes: 0,
            tags: [],
            lastModified: Date(),
            files: []
        )
        noFilesModel.detectedBackends = [SendableModel.Backend.mlx]
        #expect(noFilesModel.isValidModel == false)

        // Invalid - no backends
        let noBackendsModel: DiscoveredModel = DiscoveredModel(
            id: "test/model",
            name: "model",
            author: "test",
            downloads: 0,
            likes: 0,
            tags: [],
            lastModified: Date(),
            files: [ModelFile(path: "model.bin")]
        )
        #expect(noBackendsModel.isValidModel == false)
    }

    @Test("DiscoveredModel equality")
    @MainActor
    func testEquality() {
        let date: Date = Date()
        let files: [ModelFile] = [ModelFile(path: "test.bin")]

        let model1: DiscoveredModel = DiscoveredModel(
            id: "test/model",
            name: "model",
            author: "test",
            downloads: 100,
            likes: 10,
            tags: ["tag1"],
            lastModified: date,
            files: files
        )
        model1.detectedBackends = [SendableModel.Backend.mlx]

        let model2: DiscoveredModel = DiscoveredModel(
            id: "test/model",
            name: "model",
            author: "test",
            downloads: 100,
            likes: 10,
            tags: ["tag1"],
            lastModified: date,
            files: files
        )
        model2.detectedBackends = [SendableModel.Backend.mlx]

        let model3: DiscoveredModel = DiscoveredModel(
            id: "different/model",
            name: "model",
            author: "test",
            downloads: 100,
            likes: 10,
            tags: ["tag1"],
            lastModified: date,
            files: files
        )
        model3.detectedBackends = [SendableModel.Backend.mlx]

        #expect(model1 == model2)
        #expect(model1 != model3)
    }

    // Helper to create test models
    @MainActor
    private func createModel(
        name: String = "test-model",
        tags: [String] = []
    ) -> DiscoveredModel {
        DiscoveredModel(
            id: "test/\(name)",
            name: name,
            author: "test",
            downloads: 0,
            likes: 0,
            tags: tags,
            lastModified: Date()
        ) as DiscoveredModel
    }
}
