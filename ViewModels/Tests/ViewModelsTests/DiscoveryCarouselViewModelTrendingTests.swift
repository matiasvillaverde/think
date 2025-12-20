@testable import Abstractions
@testable import AbstractionsTestUtilities
import DataAssets
import Foundation
import Testing
@testable import ViewModels

@Suite("DiscoveryCarouselViewModel Trending Tests")
internal struct DiscoveryCarouselViewModelTrendingTests {
    @MainActor
    private func createTestModel(
        id: String,
        tags: [String],
        detectedBackends: [SendableModel.Backend],
        files: [ModelFile]
    ) -> DiscoveredModel {
        let model: DiscoveredModel = DiscoveredModel(
            id: id,
            name: id.split(separator: "/").last.map(String.init) ?? id,
            author: "test-author",
            downloads: 1_000,
            likes: 100,
            tags: tags,
            lastModified: Date(),
            files: files,
            license: "apache-2.0",
            licenseUrl: nil,
            metadata: [:]
        )
        model.enrich(with: EnrichedModelDetails(
            modelCard: nil,
            cardData: nil,
            imageUrls: [],
            detectedBackends: detectedBackends
        ))
        return model
    }

    @Test("Trending models filter to MLX or GGUF language models")
    func testTrendingFiltersSupportedBackends() async throws {
        let mockExplorer: MockCommunityModelsExplorer = MockCommunityModelsExplorer()
        let mockChecker: MockDeviceCompatibilityChecker = MockDeviceCompatibilityChecker()
        let mockCalculator: MockVRAMCalculator = MockVRAMCalculator()

        let mlxModel: DiscoveredModel = await createTestModel(
            id: "mlx-community/Test-MLX",
            tags: ["text-generation"],
            detectedBackends: [.mlx],
            files: [ModelFile(path: "model.safetensors", size: 10)]
        )
        let ggufModel: DiscoveredModel = await createTestModel(
            id: "lmstudio-community/Test-GGUF",
            tags: ["text-generation"],
            detectedBackends: [.gguf],
            files: [ModelFile(path: "model.gguf", size: 10)]
        )
        let diffusionModel: DiscoveredModel = await createTestModel(
            id: "coreml-community/Test-Diffusion",
            tags: ["diffusion"],
            detectedBackends: [.coreml],
            files: [ModelFile(path: "model.mlpackage", size: 10)]
        )

        mockExplorer.searchPaginatedResponses[.trending] = ModelPage(
            models: [mlxModel, ggufModel, diffusionModel],
            hasNextPage: false,
            nextPageToken: nil,
            totalCount: 3
        )

        let viewModel: DiscoveryCarouselViewModel = DiscoveryCarouselViewModel(
            communityExplorer: mockExplorer,
            deviceChecker: mockChecker,
            vramCalculator: mockCalculator
        )

        let models: [DiscoveredModel] = try await viewModel.trendingModels(limit: 10)
        let modelIds: [String] = await MainActor.run { models.map(\.id) }

        #expect(modelIds.contains("mlx-community/Test-MLX"))
        #expect(modelIds.contains("lmstudio-community/Test-GGUF"))
        #expect(!modelIds.contains("coreml-community/Test-Diffusion"))
    }

    @Test("Best model for device prefers higher memory requirement")
    func testBestModelForDevice() async {
        let mockExplorer: MockCommunityModelsExplorer = MockCommunityModelsExplorer()
        let mockChecker: MockDeviceCompatibilityChecker = MockDeviceCompatibilityChecker()
        let mockCalculator: MockVRAMCalculator = MockVRAMCalculator()

        let deviceMemory: DeviceMemoryInfo = DeviceMemoryInfo(
            totalMemory: 4 * RecommendedModels.MemorySize.GB,
            availableMemory: 4 * RecommendedModels.MemorySize.GB,
            usedMemory: 0,
            platform: .macOS,
            hasUnifiedMemory: true
        )
        mockChecker.memoryInfo = deviceMemory
        mockChecker.compatibilityResult = .fullGPUOffload(availableMemory: 4 * RecommendedModels.MemorySize.GB)

        let tierModels: [String] = RecommendedModels.getLanguageModelsForExactTier(forMemory: deviceMemory.totalMemory)
        let smallModelId: String = tierModels.first ?? "mlx-community/Qwen3-0.6B-4bit"
        let largeModelId: String = tierModels.dropFirst().first ?? "mlx-community/Qwen3-1.7B-4bit"

        let smallModel: DiscoveredModel = await createTestModel(
            id: smallModelId,
            tags: ["text-generation"],
            detectedBackends: [.mlx],
            files: [ModelFile(path: "model.safetensors", size: 10)]
        )
        let largeModel: DiscoveredModel = await createTestModel(
            id: largeModelId,
            tags: ["text-generation"],
            detectedBackends: [.mlx],
            files: [ModelFile(path: "model.safetensors", size: 10_000)]
        )

        mockExplorer.discoverModelResponses[smallModelId] = smallModel
        mockExplorer.discoverModelResponses[largeModelId] = largeModel

        let viewModel: DiscoveryCarouselViewModel = DiscoveryCarouselViewModel(
            communityExplorer: mockExplorer,
            deviceChecker: mockChecker,
            vramCalculator: mockCalculator
        )

        let bestModel: DiscoveredModel? = await viewModel.bestModelForDevice()
        let bestId: String? = await MainActor.run { bestModel?.id }
        #expect(bestId == largeModelId)
    }
}
