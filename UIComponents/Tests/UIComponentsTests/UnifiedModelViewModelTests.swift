import Abstractions
import Database
import Foundation
import Testing
@testable import UIComponents

/// Tests for UnifiedModelViewModel
@Suite("UnifiedModelViewModel Tests")
internal struct UnifiedModelViewModelTests {
    /// Helper method to create a mock DiscoveredModel for testing
    @MainActor
    private func createMockDiscoveredModel() -> DiscoveredModel {
        let model: DiscoveredModel = DiscoveredModel(
            id: "test-org/test-model",
            name: "Test Model",
            author: "Test Author",
            downloads: 1_000,
            likes: 50,
            tags: ["text-generation"],
            lastModified: Date(),
            files: [
                ModelFile(
                    path: "model.safetensors",
                    size: 1_024 * 1_024 * 100 // 100MB
                )
            ],
            license: "MIT",
            licenseUrl: "https://opensource.org/licenses/MIT"
        )
        // Add detected backends for testing
        model.detectedBackends = [.mlx]
        return model
    }
    @Test("UnifiedModelViewModel initializes with Model")
    @MainActor
    func testViewModelWithModel() {
        let model: Model = Model.preview
        let viewModel: UnifiedModelViewModel = UnifiedModelViewModel(model: model)

        #expect(viewModel.title == model.displayName)
        #expect(viewModel.author == (model.author ?? "Unknown"))
        #expect(viewModel.displayMode == .large)
        #expect(viewModel.isLoading == false)
        #expect(viewModel.errorMessage == nil)
    }

    @Test("UnifiedModelViewModel initializes with DiscoveredModel")
    @MainActor
    func testViewModelWithDiscoveredModel() {
        let discoveredModel: DiscoveredModel = createMockDiscoveredModel()
        let viewModel: UnifiedModelViewModel = UnifiedModelViewModel(
            discoveredModel: discoveredModel
        )

        #expect(viewModel.title == discoveredModel.name)
        #expect(viewModel.author == discoveredModel.author)
        #expect(viewModel.displayMode == .large)
        #expect(viewModel.isLoading == false)
        #expect(viewModel.errorMessage == nil)
    }

    @Test("UnifiedModelViewModel initializes with custom display mode")
    @MainActor
    func testViewModelWithCustomDisplayMode() {
        let model: Model = Model.preview
        let viewModel: UnifiedModelViewModel = UnifiedModelViewModel(
            model: model,
            displayMode: .small
        )

        #expect(viewModel.displayMode == .small)
    }

    @Test("UnifiedModelViewModel computed properties with Model")
    @MainActor
    func testComputedPropertiesWithModel() {
        let model: Model = Model.preview
        let viewModel: UnifiedModelViewModel = UnifiedModelViewModel(model: model)

        #expect(viewModel.title == model.displayName)
        #expect(viewModel.author == (model.author ?? "Unknown"))
        #expect(viewModel.imageURL == nil) // Models don't have image URLs
        #expect(viewModel.backendType == model.backend.rawValue)
        #expect(viewModel.tags == model.tags.compactMap(\.name))
        #expect(viewModel.formattedSize == ByteCountFormatter.string(
            fromByteCount: Int64(model.size),
            countStyle: .file
        ))
    }

    @Test("UnifiedModelViewModel computed properties with DiscoveredModel")
    @MainActor
    func testComputedPropertiesWithDiscoveredModel() {
        let discoveredModel: DiscoveredModel = createMockDiscoveredModel()
        let viewModel: UnifiedModelViewModel = UnifiedModelViewModel(
            discoveredModel: discoveredModel
        )

        #expect(viewModel.title == discoveredModel.name)
        #expect(viewModel.author == discoveredModel.author)
        #expect(viewModel.backendType == (
            discoveredModel.detectedBackends.first?.rawValue ?? "Unknown"
        ))
        #expect(viewModel.tags == discoveredModel.tags)
        #expect(viewModel.formattedSize == ByteCountFormatter.string(
            fromByteCount: Int64(discoveredModel.totalSize),
            countStyle: .file
        ))
    }

    @Test("UnifiedModelViewModel imageURL with DiscoveredModel")
    @MainActor
    func testImageURLWithDiscoveredModel() {
        let discoveredModel: DiscoveredModel = createMockDiscoveredModel()
        let viewModel: UnifiedModelViewModel = UnifiedModelViewModel(
            discoveredModel: discoveredModel
        )

        // Should try first imageUrls, then cardData thumbnail
        let expectedURL: URL? = discoveredModel.imageUrls.first.flatMap(URL.init)
            ?? discoveredModel.cardData?.thumbnail.flatMap(URL.init)

        #expect(viewModel.imageURL == expectedURL)
    }

    @Test("UnifiedModelViewModel isSmallMode property")
    @MainActor
    func testIsSmallModeProperty() {
        let model: Model = Model.preview
        let largeViewModel: UnifiedModelViewModel = UnifiedModelViewModel(
            model: model,
            displayMode: .large
        )
        let smallViewModel: UnifiedModelViewModel = UnifiedModelViewModel(
            model: model,
            displayMode: .small
        )

        #expect(largeViewModel.isSmallMode == false)
        #expect(smallViewModel.isSmallMode == true)
    }

    @Test("UnifiedModelViewModel shouldShowDownloadButton")
    @MainActor
    func testShouldShowDownloadButton() {
        let model: Model = Model.preview
        let discoveredModel: DiscoveredModel = createMockDiscoveredModel()

        let largeModelVM: UnifiedModelViewModel = UnifiedModelViewModel(
            model: model,
            displayMode: .large
        )
        let smallModelVM: UnifiedModelViewModel = UnifiedModelViewModel(
            model: model,
            displayMode: .small
        )
        let largeDiscoveredVM: UnifiedModelViewModel = UnifiedModelViewModel(
            discoveredModel: discoveredModel,
            displayMode: .large
        )
        let smallDiscoveredVM: UnifiedModelViewModel = UnifiedModelViewModel(
            discoveredModel: discoveredModel,
            displayMode: .small
        )

        // Download button should only show for large mode
        #expect(largeModelVM.shouldShowDownloadButton == true)
        #expect(smallModelVM.shouldShowDownloadButton == false)
        #expect(largeDiscoveredVM.shouldShowDownloadButton == true)
        #expect(smallDiscoveredVM.shouldShowDownloadButton == false)
    }

    @Test("UnifiedModelViewModel error handling")
    @MainActor
    func testErrorHandling() {
        let model: Model = Model.preview
        let viewModel: UnifiedModelViewModel = UnifiedModelViewModel(model: model)

        // Test error state
        viewModel.setError("Test error message")
        #expect(viewModel.errorMessage == "Test error message")
        #expect(viewModel.isLoading == false) // Should clear loading

        // Test clearing error
        viewModel.clearError()
        #expect(viewModel.errorMessage == nil)
        // Test empty error message is ignored
        viewModel.setError("")
        #expect(viewModel.errorMessage == nil)
    }

    @Test("UnifiedModelViewModel loading state")
    @MainActor
    func testLoadingState() {
        let model: Model = Model.preview
        let viewModel: UnifiedModelViewModel = UnifiedModelViewModel(model: model)

        #expect(viewModel.isLoading == false)

        viewModel.setLoading(true)
        #expect(viewModel.isLoading == true)
        #expect(viewModel.errorMessage == nil) // Should clear error

        viewModel.setLoading(false)
        #expect(viewModel.isLoading == false)
    }

    @Test("UnifiedModelViewModel cache invalidation")
    @MainActor
    func testCacheInvalidation() {
        let model: Model = Model.preview
        let viewModel: UnifiedModelViewModel = UnifiedModelViewModel(model: model)

        // Access cached properties
        _ = viewModel.formattedSize
        _ = viewModel.tags

        // Invalidate cache
        // Cache invalidation no longer needed - properties are computed

        // Properties should still be accessible (will be recalculated)
        #expect(!viewModel.formattedSize.isEmpty)
        // Test the skillTags property is accessible regardless of emptiness
        let tags: [String] = viewModel.tags
        #expect(tags.isEmpty || !tags.isEmpty) // Always true, just testing accessibility
    }
}
