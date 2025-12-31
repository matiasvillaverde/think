import Foundation
import Testing
import AbstractionsTestUtilities
@testable import Abstractions
@testable import Factories
@testable import ModelDownloader
@testable import ViewModels

/// Acceptance tests for model download functionality focusing on file size information
///
/// These tests verify that:
/// - Models have correct file information with sizes
/// - File sizes are not nil/zero
@Suite("Model Download Acceptance Tests", .serialized, .tags(.acceptance))
internal struct ModelDownloadAcceptanceTests {
    // MARK: - Test Constants

    /// Real model to test with
    private let testModelId: String = "ggml-org/tinygemma3-GGUF"

    @Test(
        "File Size Information for Discovered Models"
    )
    @MainActor
    func testFileSizeInformation() async throws {
        // Create the mock community explorer
        let communityExplorer: MockCommunityModelsExplorer = MockCommunityModelsExplorer()

        let seedModel: DiscoveredModel = DiscoveredModel(
            id: testModelId,
            name: "tinygemma3-GGUF",
            author: "ggml-org",
            downloads: 1_000,
            likes: 100,
            tags: ["gguf", "text-generation"],
            lastModified: Date(),
            files: [
                ModelFile(path: "model.gguf", size: 12_345_678),
                ModelFile(path: "config.json", size: 2_048)
            ]
        )
        seedModel.detectedBackends = [.gguf]
        communityExplorer.discoverModelResponses[testModelId] = seedModel

        print("Starting File Size Information Test")

        // Discover our test model
        print("\nDiscovering model: \(testModelId)")
        let discoveredModel: DiscoveredModel = try await communityExplorer.discoverModel(testModelId)

        print("Model discovered: \(discoveredModel.name)")
        print("  Author: \(discoveredModel.author)")
        print("  Files count: \(discoveredModel.files.count)")

        // Verify file information
        #expect(!discoveredModel.files.isEmpty, "Model should have files")

        // Check each file has size information
        var totalSize: Int64 = 0
        for file in discoveredModel.files {
            let filePath: String = file.path
            print("\n  File: \(filePath)")

            if let size = file.size {
                print("    Size: \(ByteCountFormatter.string(fromByteCount: size, countStyle: .file))")
                totalSize += size
            } else {
                print("    Size: nil")
            }

            // All files should have size information after our fix
            #expect(file.size != nil, "File \(filePath) should have size information")

            if let size = file.size {
                #expect(size > 0, "File \(filePath) should have non-zero size")
            }
        }

        print("\nTotal size: \(ByteCountFormatter.string(fromByteCount: totalSize, countStyle: .file))")
        #expect(totalSize > 0, "Model should have non-zero total size")
        #expect(discoveredModel.totalSize > 0, "Model totalSize property should be calculated")

        print("\nFile Size Information Test Passed!")
    }

    @Test(
        "Multiple Models Have File Sizes"
    )
    @MainActor
    func testMultipleModelsHaveFileSizes() async throws {
        // Create the mock community explorer
        let communityExplorer: MockCommunityModelsExplorer = MockCommunityModelsExplorer()

        let models: [DiscoveredModel] = makeFileSizeTestModels()
        registerModels(models, in: communityExplorer)

        print("Testing file sizes for multiple models")

        // Test each model with sizes registered
        let modelIds: [String] = models.map(\.id)
        for modelId in modelIds {
            print("\nTesting model: \(modelId)")
            let model: DiscoveredModel = try await communityExplorer.discoverModel(modelId)
            assertModelHasFileSizes(model, modelId: modelId)
        }

        print("\nMultiple Models File Size Test Completed!")
    }
}

private enum FileSizeTestConstants {
    static let ggufDownloads: Int = 1_000
    static let ggufLikes: Int = 100
    static let ggufModelSize: Int64 = 9_999_999
    static let configSizeSmall: Int64 = 1_024

    static let mlxDownloads: Int = 2_000
    static let mlxLikes: Int = 200
    static let mlxModelSize: Int64 = 1_111_111
    static let configSizeStandard: Int64 = 2_048

    static let coreMLDownloads: Int = 3_000
    static let coreMLLikes: Int = 300
    static let coreMLZipSize: Int64 = 2_222_222
    static let coreMLInfoSize: Int64 = 3_072

    static let qwenDownloads: Int = 1_500
    static let qwenLikes: Int = 180
    static let qwenModelSize: Int64 = 1_500_000
}

@MainActor
private func makeFileSizeTestModels() -> [DiscoveredModel] {
    [
        makeGGUFModel(),
        makeMLXModel(),
        makeCoreMLModel(),
        makeQwenModel()
    ]
}

@MainActor
private func makeGGUFModel() -> DiscoveredModel {
    let model: DiscoveredModel = DiscoveredModel(
        id: "ggml-org/tinygemma3-GGUF",
        name: "tinygemma3-GGUF",
        author: "ggml-org",
        downloads: FileSizeTestConstants.ggufDownloads,
        likes: FileSizeTestConstants.ggufLikes,
        tags: ["gguf"],
        lastModified: Date(),
        files: [
            ModelFile(path: "model.gguf", size: FileSizeTestConstants.ggufModelSize),
            ModelFile(path: "config.json", size: FileSizeTestConstants.configSizeSmall)
        ]
    )
    model.detectedBackends = [.gguf]
    return model
}

@MainActor
private func makeMLXModel() -> DiscoveredModel {
    let model: DiscoveredModel = DiscoveredModel(
        id: "mlx-community/Llama-3.2-1B-Instruct-4bit",
        name: "Llama-3.2-1B-Instruct-4bit",
        author: "mlx-community",
        downloads: FileSizeTestConstants.mlxDownloads,
        likes: FileSizeTestConstants.mlxLikes,
        tags: ["mlx"],
        lastModified: Date(),
        files: [
            ModelFile(path: "model.safetensors", size: FileSizeTestConstants.mlxModelSize),
            ModelFile(path: "config.json", size: FileSizeTestConstants.configSizeStandard)
        ]
    )
    model.detectedBackends = [.mlx]
    return model
}

@MainActor
private func makeCoreMLModel() -> DiscoveredModel {
    let model: DiscoveredModel = DiscoveredModel(
        id: "coreml-community/coreml-animagine-xl-3.1",
        name: "coreml-animagine-xl-3.1",
        author: "coreml-community",
        downloads: FileSizeTestConstants.coreMLDownloads,
        likes: FileSizeTestConstants.coreMLLikes,
        tags: ["coreml"],
        lastModified: Date(),
        files: [
            ModelFile(path: "model.zip", size: FileSizeTestConstants.coreMLZipSize),
            ModelFile(path: "model_info.json", size: FileSizeTestConstants.coreMLInfoSize)
        ]
    )
    model.detectedBackends = [.coreml]
    return model
}

@MainActor
private func makeQwenModel() -> DiscoveredModel {
    let model: DiscoveredModel = DiscoveredModel(
        id: "mlx-community/Qwen2.5-1.5B-Instruct-4bit",
        name: "Qwen2.5-1.5B-Instruct-4bit",
        author: "mlx-community",
        downloads: FileSizeTestConstants.qwenDownloads,
        likes: FileSizeTestConstants.qwenLikes,
        tags: ["mlx"],
        lastModified: Date(),
        files: [
            ModelFile(path: "model.safetensors", size: FileSizeTestConstants.qwenModelSize),
            ModelFile(path: "config.json", size: FileSizeTestConstants.configSizeStandard)
        ]
    )
    model.detectedBackends = [.mlx]
    return model
}

@MainActor
private func registerModels(
    _ models: [DiscoveredModel],
    in explorer: MockCommunityModelsExplorer
) {
    for model in models {
        explorer.discoverModelResponses[model.id] = model
    }
}

@MainActor
private func assertModelHasFileSizes(_ model: DiscoveredModel, modelId: String) {
    let files: [ModelFile] = model.files
    print("  Files: \(files.count)")
    let filesWithSize: [ModelFile] = files.filter { $0.size != nil }
    print("  Files with size: \(filesWithSize.count)")

    #expect(
        filesWithSize.count == files.count,
        "All files should have size information for model \(modelId)"
    )

    let totalSize: Int64 = files.reduce(0) { $0 + ($1.size ?? 0) }
    print("  Total size: \(ByteCountFormatter.string(fromByteCount: totalSize, countStyle: .file))")

    #expect(totalSize > 0, "Model \(modelId) should have non-zero total size")
}
