import Foundation
import Testing
@testable import Abstractions
@testable import AbstractionsTestUtilities
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
        "File Size Information for Discovered Models",
        .disabled(
            "Disabled: This test queries HuggingFace API which may be unavailable (HTTP 503)"
        )
    )
    @MainActor
    func testFileSizeInformation() async throws {
        // Create the community explorer to discover models
        let communityExplorer: CommunityModelsExplorer = CommunityModelsExplorer()

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
            print("\n  File: \(file.path)")

            if let size = file.size {
                print("    Size: \(ByteCountFormatter.string(fromByteCount: size, countStyle: .file))")
                totalSize += size
            } else {
                print("    Size: nil")
            }

            // All files should have size information after our fix
            #expect(file.size != nil, "File \(file.path) should have size information")

            if let size = file.size {
                #expect(size > 0, "File \(file.path) should have non-zero size")
            }
        }

        print("\nTotal size: \(ByteCountFormatter.string(fromByteCount: totalSize, countStyle: .file))")
        #expect(totalSize > 0, "Model should have non-zero total size")
        #expect(discoveredModel.totalSize > 0, "Model totalSize property should be calculated")

        print("\nFile Size Information Test Passed!")
    }

    @Test(
        "Multiple Models Have File Sizes",
        .disabled(
            "Disabled: This test queries HuggingFace API which may be unavailable (HTTP 503)"
        )
    )
    @MainActor
    func testMultipleModelsHaveFileSizes() async throws {
        // Create the community explorer
        let communityExplorer: CommunityModelsExplorer = CommunityModelsExplorer()

        print("Testing file sizes for multiple models")

        // Test a few different models
        let modelIds: [String] = [
            "ggml-org/tinygemma3-GGUF",
            "mlx-community/Llama-3.2-1B-Instruct-4bit",
            "mlx-community/Qwen2.5-1.5B-Instruct-4bit"
        ]

        for modelId in modelIds {
            print("\nTesting model: \(modelId)")

            do {
                let model: DiscoveredModel = try await communityExplorer.discoverModel(modelId)

                print("  Files: \(model.files.count)")
                let filesWithSize: [ModelFile] = model.files.filter { $0.size != nil }
                print("  Files with size: \(filesWithSize.count)")

                // All files should have sizes
                #expect(
                    filesWithSize.count == model.files.count,
                    "All files should have size information for model \(modelId)"
                )

                let totalSize: Int64 = model.files.reduce(0) { $0 + ($1.size ?? 0) }
                print("  Total size: \(ByteCountFormatter.string(fromByteCount: totalSize, countStyle: .file))")

                #expect(totalSize > 0, "Model \(modelId) should have non-zero total size")
            } catch {
                print("  Failed to discover model: \(error)")
                // Continue with other models
            }
        }

        print("\nMultiple Models File Size Test Completed!")
    }
}
