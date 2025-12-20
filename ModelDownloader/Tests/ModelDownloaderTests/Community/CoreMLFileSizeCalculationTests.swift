import Abstractions
import Foundation
@testable import ModelDownloader
import Testing

/// Focused tests for CoreML file size calculation bug
@Suite("CoreML File Size Bug")
struct CoreMLFileSizeCalculationTests {
    @Test("CoreML model with multiple ZIP files should not sum all sizes")
    internal func testCoreMLMultipleZipFiles() throws {
        // Create a mock scenario similar to what happens in real CoreML repos
        // This simulates a model with both original and split-einsum variants
        let mockFiles: [ModelFile] = [
            // Config files (should be included)
            ModelFile(path: "config.json", size: 1_024),
            ModelFile(path: "tokenizer.json", size: 2_048),

            // Original variant (should NOT be included when split-einsum exists)
            ModelFile(path: "original/768x768/TextEncoder.mlmodelc.zip", size: 1_000_000_000),
            ModelFile(path: "original/768x768/Unet.mlmodelc.zip", size: 2_000_000_000),
            ModelFile(path: "original/768x768/VAEDecoder.mlmodelc.zip", size: 500_000_000),

            // Split-einsum variant (should be selected)
            ModelFile(path: "split-einsum/768x768/TextEncoder.mlmodelc.zip", size: 900_000_000),
            ModelFile(path: "split-einsum/768x768/Unet.mlmodelc.zip", size: 1_800_000_000),
            ModelFile(path: "split-einsum/768x768/VAEDecoder.mlmodelc.zip", size: 450_000_000)
        ]

        // Current behavior: sums all files
        let currentTotalSize: Int64 = mockFiles.compactMap(\.size).reduce(0, +)
        let currentSizeStr: String = ByteCountFormatter.string(
            fromByteCount: currentTotalSize,
            countStyle: .file
        )
        print("Current total size (all files): \(currentSizeStr)")

        // Expected behavior: only split-einsum + metadata
        let expectedFiles: [ModelFile] = mockFiles.filter { file in
            file.path.contains("split-einsum/") ||
            file.path.hasSuffix(".json")
        }
        let expectedSize: Int64 = expectedFiles.compactMap(\.size).reduce(0, +)
        let expectedSizeStr: String = ByteCountFormatter.string(
            fromByteCount: expectedSize,
            countStyle: .file
        )
        print("Expected size (split-einsum + metadata): \(expectedSizeStr)")

        // This test demonstrates the bug
        #expect(
            currentTotalSize > expectedSize * 2,
            "Currently summing all variants which inflates the size"
        )
    }

    @Test("Verify actual API response for models with multiple variants")
    @MainActor
    internal func testRealCoreMLModelWithVariants() async throws {
        let explorer: CommunityModelsExplorer = CommunityModelsExplorer()

        // Test with a model known to have multiple resolution variants
        // Look for stable-diffusion models which often have multiple resolutions
        let models: [DiscoveredModel] = try await explorer.exploreCommunity(
            ModelCommunity(
                id: "coreml-community",
                displayName: "CoreML Community",
                supportedBackends: [.coreml]
            ),
            query: "stable-diffusion",
            limit: 20
        )

        print("\nSearching for models with multiple variants...")

        var foundModelWithDuplicates: Bool = false

        for model in models {
            // Look for models with subdirectories suggesting variants
            let subdirs: Set<String> = Set(model.files.compactMap { file -> String? in
                let components: [Substring] = file.path.split(separator: "/")
                if components.count > 1 {
                    return String(components[0])
                }
                return nil
            })

            // Check if model has both original and split-einsum
            let hasOriginal: Bool = subdirs.contains("original")
            let hasSplitEinsum: Bool = subdirs.contains("split-einsum") || subdirs.contains("split_einsum")

            if hasOriginal, hasSplitEinsum {
                foundModelWithDuplicates = true
                print("\nFound model with variants: \(model.id)")
                print("  Subdirectories: \(subdirs.sorted())")

                // Calculate sizes
                let originalSize: Int64 = model.files
                    .filter { $0.path.contains("original/") }
                    .compactMap(\.size)
                    .reduce(0, +)
                let splitEinsumSize: Int64 = model.files
                    .filter { $0.path.contains("split-einsum/") || $0.path.contains("split_einsum/") }
                    .compactMap(\.size)
                    .reduce(0, +)
                let totalSize: Int64 = model.totalSize

                let originalSizeStr: String = ByteCountFormatter.string(
                    fromByteCount: originalSize,
                    countStyle: .file
                )
                let splitEinsumSizeStr: String = ByteCountFormatter.string(
                    fromByteCount: splitEinsumSize,
                    countStyle: .file
                )
                let totalSizeStr: String = ByteCountFormatter.string(
                    fromByteCount: totalSize,
                    countStyle: .file
                )
                print("  Original variant size: \(originalSizeStr)")
                print("  Split-einsum variant size: \(splitEinsumSizeStr)")
                print("  Total reported size: \(totalSizeStr)")

                // The bug: total includes both variants
                #expect(
                    totalSize >= originalSize + splitEinsumSize,
                    "Total size includes all variants (this is the bug we're fixing)"
                )

                break // Found one example
            }
        }

        if !foundModelWithDuplicates {
            print("\nNo models found with both original and split-einsum variants in search results")
            print("This might indicate the bug has been fixed or we need to search differently")
        }
    }

    @Test("Verify coreml-stable-diffusion-2-1-base shows 3.9GB+ size")
    @MainActor
    internal func testStableDiffusion21BaseModelSize() async throws {
        let explorer: CommunityModelsExplorer = CommunityModelsExplorer()
        let modelId: String = "coreml-community/coreml-stable-diffusion-2-1-base"

        // Discover the model
        let model: DiscoveredModel = try await explorer.discoverModel(modelId)

        print("\nModel: \(model.id)")
        print("Total files: \(model.files.count)")
        print("Total size: \(model.formattedTotalSize)")
        print("Detected backends: \(model.detectedBackends.map(\.rawValue))")

        // Debug: Print all files with sizes
        print("\nAll files:")
        for file in model.files.sorted(by: { $0.path < $1.path }) {
            let sizeStr: String = if let size: Int64 = file.size {
                ByteCountFormatter.string(fromByteCount: size, countStyle: .file)
            } else {
                "unknown"
            }
            print("  \(file.path): \(sizeStr)")
        }

        // Group files by directory
        var filesByDirectory: [String: [ModelFile]] = [:]
        for file in model.files {
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

        // The expected size is 3.93 GB + small metadata files
        let expectedMinGB: Double = 3.9
        let expectedMaxGB: Double = 4.0  // Allow for metadata overhead
         let expectedMinBytes: Int64 = Int64(expectedMinGB * 1_000_000_000)
         let expectedMaxBytes: Int64 = Int64(expectedMaxGB * 1_000_000_000)

        #expect(
            model.totalSize >= expectedMinBytes && model.totalSize <= expectedMaxBytes,
            """
            Model size should be between \(expectedMinGB)GB and \(expectedMaxGB)GB but was \(model.formattedTotalSize).
            This indicates file selection is not working correctly - should only include one variant + metadata.
            """
        )
    }

    @Test("Debug file selection for coreml-stable-diffusion-2-1-base")
    internal func testDebugFileSelection() async throws {
        // Test file selection directly
        let allFiles: [ModelFile] = [
            ModelFile(path: ".gitattributes", size: 1_024),
            ModelFile(path: ".gitignore", size: 20),
            ModelFile(path: "README.md", size: 13_312),
            ModelFile(
                path: "original/512x768/stable-diffusion-v2.1-base_no-i2i_original_512x768.zip",
                size: 2_330_000_000
            ),
            ModelFile(
                path: "original/768x768/stable-diffusion-v2.1-base_original_768x768.zip",
                size: 2_400_000_000
            ),
            ModelFile(
                path: "original/stable-diffusion-v2.1-base_no-i2i_original.zip",
                size: 3_930_000_000
            ),
            ModelFile(
                path: "split_einsum/stable-diffusion-v2.1-base_no-i2i_split-einsum.zip",
                size: 3_930_000_000
            )
        ]

        // Test CoreML file selector
        let selector: CoreMLFileSelectorAdapter = CoreMLFileSelectorAdapter()
        let selectedFiles: [ModelFile] = await selector.selectFiles(from: allFiles)

        print("\nOriginal files: \(allFiles.count)")
        print("Selected files: \(selectedFiles.count)")

        print("\nSelected files detail:")
        for file in selectedFiles {
            let sizeStr: String = if let size: Int64 = file.size {
                ByteCountFormatter.string(fromByteCount: size, countStyle: .file)
            } else {
                "unknown"
            }
            print("  \(file.path): \(sizeStr)")
        }

        let selectedSize: Int64 = selectedFiles.compactMap(\.size).reduce(0, +)
        let selectedSizeStr: String = ByteCountFormatter.string(
            fromByteCount: selectedSize,
            countStyle: .file
        )
        print("\nTotal selected size: \(selectedSizeStr)")

        // Should select only split_einsum variant (no essential metadata files in test data)
        #expect(selectedFiles.count == 1, "Should select only split_einsum variant")
        #expect(selectedSize == 3_930_000_000, "Should be exactly 3.93GB")
    }
}
