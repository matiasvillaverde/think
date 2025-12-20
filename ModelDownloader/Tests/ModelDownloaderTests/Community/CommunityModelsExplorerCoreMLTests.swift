import Abstractions
import Foundation
@testable import ModelDownloader
import Testing

/// Tests for CoreML model file size calculation in CommunityModelsExplorer
@Suite("HuggingFace API", .serialized)
struct APITests {
    @Test(
        "Parse CoreML community models with correct file sizes using real API"
    )
    internal func testCoreMLModelFileSizeParsing() async throws {
        // Given: CommunityModelsExplorer with real HuggingFace API
        let explorer: CommunityModelsExplorer = CommunityModelsExplorer()

        // When: Exploring coreml-community models
        let models: [DiscoveredModel] = try await explorer.exploreCommunity(
            ModelCommunity(
                id: "coreml-community",
                displayName: "CoreML Community",
                supportedBackends: [.coreml]
            ),
            limit: 5
        )

        // Then: File sizes should match what would actually be downloaded
        #expect(!models.isEmpty, "Should find CoreML models")

        for model: DiscoveredModel in models {
            print("Model: \(await model.id)")
            print("  Total files: \(await model.files.count)")
            print("  Total size: \(await model.formattedTotalSize)")

            // Check if this is a model with subdirectories (variants)
            let hasVariants: Bool = await model.files.contains { file in
                file.path.contains("split-einsum/") || file.path.contains("split_einsum/") ||
                file.path.contains("original/")
            }

            if hasVariants {
                print("  Has variants: YES")

                // Count files by variant
                let splitEinsumFiles: [ModelFile] = await model.files.filter { file in
                    file.path.contains("split-einsum/") || file.path.contains("split_einsum/")
                }
                let originalFiles: [ModelFile] = await model.files.filter { file in
                    file.path.contains("original/")
                }

                print("  Split-einsum files: \(splitEinsumFiles.count)")
                print("  Original files: \(originalFiles.count)")

                // File sizes should not include duplicate variants
                // This test will initially fail because we're summing all files
                let splitEinsumSize: Int64 = splitEinsumFiles.compactMap(\.size).reduce(0, +)
                let originalSize: Int64 = originalFiles.compactMap(\.size).reduce(0, +)
                let totalSize: Int64 = await model.totalSize

                // The total size should be approximately one variant, not both
                // Allow some overhead for metadata files
                let expectedMaxSize: Int64 = max(splitEinsumSize, originalSize) * 2 // 2x to account for metadata

                #expect(
                    totalSize <= expectedMaxSize,
                    """
                    Total size (\(totalSize)) should not include all variants. \
                    Split-einsum: \(splitEinsumSize), Original: \(originalSize)
                    """
                )
            }
        }
    }

    @Test("Compare file sizes between discovery and actual download")
    @MainActor
    internal func testFileSizeConsistencyBetweenDiscoveryAndDownload() async throws {
        // Test that DiscoveredModel.totalSize matches actual download size
        let explorer: CommunityModelsExplorer = CommunityModelsExplorer()
        // let downloader: ModelDownloader = ModelDownloader.shared

        // Use a specific CoreML model we know has variants
        let modelId: String = "coreml-community/coreml-animagine-xl-3.1"

        // Discover the model
        let discoveredModel: DiscoveredModel = try await explorer.discoverModel(modelId)
        print("Discovered model size: \(discoveredModel.formattedTotalSize)")

        // Get the files that would actually be downloaded
        let sendableModel: SendableModel = try await explorer.prepareForDownload(
            discoveredModel,
            preferredBackend: .coreml
        )

        // The discovered size should match what we'd actually download
        // This will fail initially because discovery includes all files
        #expect(
            discoveredModel.totalSize <= sendableModel.ramNeeded * 2,
            "Discovered size should be similar to download size"
        )
    }

    @Test("Verify subdirectory file handling for complex CoreML models")
    @MainActor
    internal func testSubdirectoryFileSelection() async throws {
        let explorer: CommunityModelsExplorer = CommunityModelsExplorer()

        // Test with animagine-xl-3.1 which has complex structure
        let modelId: String = "coreml-community/coreml-animagine-xl-3.1"
        let model: DiscoveredModel = try await explorer.discoverModel(modelId)

        print("Model: \(modelId)")
        print("Total files: \(model.files.count)")

        // Group files by directory structure
        var filesByDirectory: [String: [ModelFile]] = [:]
        for file: ModelFile in model.files {
            let components: [Substring] = file.path.split(separator: "/")
            let directory: String = components.count > 1 ? String(components[0]) : "root"
            filesByDirectory[directory, default: []].append(file)
        }

        print("\nFiles by directory:")
        for (dir, files) in filesByDirectory.sorted(by: { $0.key < $1.key }) {
            let size: Int64 = files.compactMap(\.size).reduce(0, +)
            let sizeStr: String = ByteCountFormatter.string(
                fromByteCount: size,
                countStyle: .file
            )
            print("  \(dir): \(files.count) files, \(sizeStr)")
        }

        // Verify that we're not counting all variants
        let hasMultipleVariants: Bool = filesByDirectory.keys.contains { key in
            key.contains("split") || key == "original"
        }

        if hasMultipleVariants {
            // Total size should reflect only one variant being selected
            let variantSizes: [Int64] = filesByDirectory.compactMap { dir, files -> Int64? in
                if dir.contains("split") || dir == "original" {
                    return files.compactMap(\.size).reduce(0, +)
                }
                return nil
            }

            let maxVariantSize: Int64 = variantSizes.max() ?? 0
            let totalSize: Int64 = model.totalSize

            print("\nVariant sizes found: \(variantSizes)")
            let maxSizeStr: String = ByteCountFormatter.string(
                fromByteCount: maxVariantSize,
                countStyle: .file
            )
            let totalSizeStr: String = ByteCountFormatter.string(
                fromByteCount: totalSize,
                countStyle: .file
            )
             let expectedMaxSize: Int64 = Int64(Double(maxVariantSize) * 1.5)
            let expectedMaxStr: String = ByteCountFormatter.string(
                fromByteCount: expectedMaxSize,
                countStyle: .file
            )
            print("Max variant size: \(maxSizeStr)")
            print("Total model size: \(totalSizeStr)")
            print("Expected max (1.5x): \(expectedMaxStr)")

            #expect(
                totalSize <= Int64(Double(maxVariantSize) * 1.5), // Allow 50% overhead for metadata
                "Total size should not include all variants"
            )
        }
    }
}
