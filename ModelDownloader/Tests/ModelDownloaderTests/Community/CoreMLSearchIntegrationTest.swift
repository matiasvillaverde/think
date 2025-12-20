import Abstractions
import Foundation
@testable import ModelDownloader
import Testing

/// Integration test to verify CoreML file size calculation in search results
@Suite("CoreML Search Integration")
struct CoreMLSearchIntegrationTest {
    @Test("CoreML models in search results should show correct file size")
    @MainActor
    internal func testCoreMLSearchResultsFileSize() async throws {
        let explorer: CommunityModelsExplorer = CommunityModelsExplorer()

        // Search for the specific model in CoreML community
        let models: [DiscoveredModel] = try await explorer.exploreCommunity(
            ModelCommunity(
                id: "coreml-community",
                displayName: "CoreML Community",
                supportedBackends: [.coreml]
            ),
            query: "stable-diffusion-2-1-base",
            limit: 10
        )

        // Find our specific model
        var targetModel: DiscoveredModel?
        for model: DiscoveredModel in models where
            await model.id == "coreml-community/coreml-stable-diffusion-2-1-base" {
            targetModel = model
            break
        }

        #expect(targetModel != nil, "Should find coreml-stable-diffusion-2-1-base in search results")

        guard let model: DiscoveredModel = targetModel else { return }

        print("\nSearch Result Model Info:")
        print("  ID: \(await model.id)")
        print("  Files count: \(await model.files.count)")
        print("  Total size: \(await model.formattedTotalSize)")
        print("  Detected backends: \(await model.detectedBackends.map(\.rawValue))")

        // Debug: Print all files
        print("\nFiles in search result:")
        for file: ModelFile in await model.files.sorted(by: { $0.path < $1.path }) {
            let sizeStr: String = if let size: Int64 = file.size {
                ByteCountFormatter.string(fromByteCount: size, countStyle: .file)
            } else {
                "unknown"
            }
            print("  \(file.path): \(sizeStr)")
        }

        // The model should have file selection applied
        #expect(model.files.count <= 10, "Should have filtered files, not all repository files")

        // Verify the size is correct (3.9GB+)
        let expectedMinGB: Double = 3.9
        let expectedMaxGB: Double = 4.0
         let expectedMinBytes: Int64 = Int64(expectedMinGB * 1_000_000_000)
         let expectedMaxBytes: Int64 = Int64(expectedMaxGB * 1_000_000_000)

        #expect(
            model.totalSize >= expectedMinBytes && model.totalSize <= expectedMaxBytes,
            """
            Model size in search results should be between \(expectedMinGB)GB and \(expectedMaxGB)GB \
            but was \(model.formattedTotalSize).
            This is what the UI will display.
            """
        )
    }

    @Test("Compare search results vs direct discovery for CoreML model")
    @MainActor
    internal func testSearchVsDirectDiscovery() async throws {
        let explorer: CommunityModelsExplorer = CommunityModelsExplorer()
        let modelId: String = "coreml-community/coreml-stable-diffusion-2-1-base"

        // Get model via search
        let searchResults: [DiscoveredModel] = try await explorer.exploreCommunity(
            ModelCommunity(
                id: "coreml-community",
                displayName: "CoreML Community",
                supportedBackends: [.coreml]
            ),
            query: "stable-diffusion-2-1-base",
            limit: 10
        )

        let searchModel: DiscoveredModel? = searchResults.first { $0.id == modelId }
        #expect(searchModel != nil, "Should find model in search results")

        // Get model via direct discovery
        let directModel: DiscoveredModel = try await explorer.discoverModel(modelId)

        print("\nComparison:")
        print("Search result:")
        print("  Files: \(searchModel?.files.count ?? 0)")
        print("  Size: \(searchModel?.formattedTotalSize ?? "N/A")")
        print("\nDirect discovery:")
        print("  Files: \(directModel.files.count)")
        print("  Size: \(directModel.formattedTotalSize)")

        // Both should have the same file count and size
        #expect(
            searchModel?.files.count == directModel.files.count,
            "Search and direct discovery should return same file count"
        )
        #expect(
            searchModel?.totalSize == directModel.totalSize,
            "Search and direct discovery should return same total size"
        )
    }
}
