import Abstractions
import Database
import SwiftUI
import Testing
@testable import UIComponents

/// Tests for UnifiedModelView component
@Suite("UnifiedModelView Tests")
internal struct UnifiedModelViewTests {
    // MARK: - Helper Methods

    /// Helper method to create a mock DiscoveredModel for testing
    @MainActor
    private func createMockDiscoveredModel() -> DiscoveredModel {
        let model: DiscoveredModel = DiscoveredModel(
            id: "test-org/test-model",
            name: "Test Model",
            author: "Test Author",
            downloads: 1_000,
            likes: 50,
            tags: ["text-generation", "llm"],
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

    // MARK: - Initialization Tests

    @Test("UnifiedModelView initializes with Model")
    @MainActor
    func testViewInitializationWithModel() {
        let model: Model = Model.preview
        let view: UnifiedModelView = UnifiedModelView(model: model)

        // Verify the view can be initialized without errors
        #expect(view.viewModel.title == model.displayName)
        #expect(view.viewModel.author == (model.author ?? "Unknown"))
        #expect(view.viewModel.displayMode == .large)
    }

    @Test("UnifiedModelView initializes with DiscoveredModel")
    @MainActor
    func testViewInitializationWithDiscoveredModel() {
        let discoveredModel: DiscoveredModel = createMockDiscoveredModel()
        let view: UnifiedModelView = UnifiedModelView(discoveredModel: discoveredModel)

        // Verify the view can be initialized without errors
        #expect(view.viewModel.title == discoveredModel.name)
        #expect(view.viewModel.author == discoveredModel.author)
        #expect(view.viewModel.displayMode == .large)
    }

    @Test("UnifiedModelView initializes with custom display mode")
    @MainActor
    func testViewInitializationWithCustomDisplayMode() {
        let model: Model = Model.preview
        let view: UnifiedModelView = UnifiedModelView(
            model: model,
            displayMode: .small
        )

        // Verify the view uses the custom display mode
        #expect(view.viewModel.displayMode == .small)
        #expect(view.viewModel.isSmallMode == true)
    }

    // MARK: - Display Mode Tests

    @Test("UnifiedModelView small mode properties")
    @MainActor
    func testSmallModeProperties() {
        let model: Model = Model.preview
        let view: UnifiedModelView = UnifiedModelView(
            model: model,
            displayMode: .small
        )

        // Verify small mode properties
        #expect(view.viewModel.isSmallMode == true)
        #expect(view.viewModel.shouldShowDownloadButton == false)
    }

    @Test("UnifiedModelView large mode properties")
    @MainActor
    func testLargeModeProperties() {
        let model: Model = Model.preview
        let view: UnifiedModelView = UnifiedModelView(
            model: model,
            displayMode: .large
        )

        // Verify large mode properties
        #expect(view.viewModel.isSmallMode == false)
        #expect(view.viewModel.shouldShowDownloadButton == true)
    }

    // MARK: - Content Display Tests

    @Test("UnifiedModelView displays Model content")
    @MainActor
    func testModelContentDisplay() {
        let model: Model = Model.preview
        let view: UnifiedModelView = UnifiedModelView(model: model)

        // Verify model content is accessible through viewModel
        #expect(view.viewModel.title == model.displayName)
        #expect(view.viewModel.author == (model.author ?? "Unknown"))
        #expect(view.viewModel.backendType == model.backend.rawValue)
        #expect(view.viewModel.tags == model.tags.compactMap(\.name))
        #expect(!view.viewModel.formattedSize.isEmpty)
    }

    @Test("UnifiedModelView displays DiscoveredModel content")
    @MainActor
    func testDiscoveredModelContentDisplay() {
        let discoveredModel: DiscoveredModel = createMockDiscoveredModel()
        let view: UnifiedModelView = UnifiedModelView(discoveredModel: discoveredModel)

        // Verify discovered model content is accessible through viewModel
        #expect(view.viewModel.title == discoveredModel.name)
        #expect(view.viewModel.author == discoveredModel.author)
        #expect(view.viewModel.backendType == (
            discoveredModel.detectedBackends.first?.rawValue ?? "Unknown"
        ))
        #expect(view.viewModel.tags == discoveredModel.tags)
        #expect(!view.viewModel.formattedSize.isEmpty)
    }

    // MARK: - Image Display Tests

    @Test("UnifiedModelView handles image URLs for DiscoveredModel")
    @MainActor
    func testImageURLHandling() {
        let discoveredModel: DiscoveredModel = createMockDiscoveredModel()
        let view: UnifiedModelView = UnifiedModelView(discoveredModel: discoveredModel)

        // Verify image URL handling
        let expectedURL: URL? = discoveredModel.imageUrls.first.flatMap(URL.init)
            ?? discoveredModel.cardData?.thumbnail.flatMap(URL.init)

        #expect(view.viewModel.imageURL == expectedURL)
    }

    @Test("UnifiedModelView handles missing image URL for Model")
    @MainActor
    func testMissingImageURLForModel() {
        let model: Model = Model.preview
        let view: UnifiedModelView = UnifiedModelView(model: model)

        // Verify Models don't have image URLs
        #expect(view.viewModel.imageURL == nil)
    }

    // MARK: - Error and Loading State Tests

    @Test("UnifiedModelView handles loading state")
    @MainActor
    func testLoadingState() {
        let model: Model = Model.preview
        let view: UnifiedModelView = UnifiedModelView(model: model)

        // Test loading state
        view.viewModel.setLoading(true)
        #expect(view.viewModel.isLoading == true)
        #expect(view.viewModel.errorMessage == nil)

        view.viewModel.setLoading(false)
        #expect(view.viewModel.isLoading == false)
    }

    @Test("UnifiedModelView handles error state")
    @MainActor
    func testErrorState() {
        let model: Model = Model.preview
        let view: UnifiedModelView = UnifiedModelView(model: model)

        // Test error state
        view.viewModel.setError("Test error message")
        #expect(view.viewModel.errorMessage == "Test error message")
        #expect(view.viewModel.isLoading == false)

        view.viewModel.clearError()
        #expect(view.viewModel.errorMessage == nil)
    }

    // MARK: - Tags Tests

    @Test("UnifiedModelView displays tags for Model")
    @MainActor
    func testTagsForModel() {
        let model: Model = Model.preview
        let view: UnifiedModelView = UnifiedModelView(model: model)

        // Verify tags are accessible
        let tags: [String] = view.viewModel.tags
        #expect(tags == model.tags.compactMap(\.name))
    }

    @Test("UnifiedModelView displays tags for DiscoveredModel")
    @MainActor
    func testTagsForDiscoveredModel() {
        let discoveredModel: DiscoveredModel = createMockDiscoveredModel()
        let view: UnifiedModelView = UnifiedModelView(discoveredModel: discoveredModel)

        // Verify tags are accessible
        let tags: [String] = view.viewModel.tags
        #expect(tags == discoveredModel.tags)
    }

    // MARK: - Cache Tests

    @Test("UnifiedModelView caches formatted properties")
    @MainActor
    func testFormattedPropertiesCaching() {
        let model: Model = Model.preview
        let view: UnifiedModelView = UnifiedModelView(model: model)

        // Access cached properties multiple times
        let size1: String = view.viewModel.formattedSize
        let size2: String = view.viewModel.formattedSize
        #expect(size1 == size2)
        #expect(!size1.isEmpty)

        // Tags should be accessible
        let tags: [String] = view.viewModel.tags
        #expect(tags == model.tags.compactMap(\.name))
    }
}
