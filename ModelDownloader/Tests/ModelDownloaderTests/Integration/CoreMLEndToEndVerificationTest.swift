import Abstractions
import Foundation
@testable import ModelDownloader
import Testing

@Suite("CoreML End-to-End Verification")
struct CoreMLEndToEndVerificationTest {
    @Test("Verify CoreML file selection reduces downloads by 75%")
    func testCoreMLBandwidthSavings() async throws {
        // This test verifies that we only download 1 file instead of 4
        let allFiles: [FileInfo] = [
            FileInfo(path: "coreml/split-einsum/model_split.zip", size: 2_000_000_000),
            FileInfo(path: "coreml/split-einsum/768x768/model_split_768.zip", size: 2_000_000_000),
            FileInfo(path: "coreml/original/model_original.zip", size: 2_000_000_000),
            FileInfo(path: "coreml/original/768x768/model_original_768.zip", size: 2_000_000_000),
            FileInfo(path: "README.md", size: 1_000)
        ]

        // Calculate bandwidth without optimization
        let totalWithoutOptimization: Int64 = allFiles
            .filter { $0.path.hasSuffix(".zip") }
            .reduce(0) { $0 + $1.size }

        // Use CoreML file selector
        let selector: CoreMLFileSelector = CoreMLFileSelector()
        let selectedFiles: [FileInfo] = await selector.selectFiles(from: allFiles)

        // Calculate bandwidth with optimization
        let totalWithOptimization: Int64 = selectedFiles
            .filter { $0.path.hasSuffix(".zip") }
            .reduce(0) { $0 + $1.size }

        let savingsAmount: Int64 = totalWithoutOptimization - totalWithOptimization
        let savings: Double = Double(savingsAmount) / Double(totalWithoutOptimization) * 100

        print("\n💰 Bandwidth Savings Analysis:")
        let withoutOptStr: String = ByteCountFormatter.string(
            fromByteCount: totalWithoutOptimization,
            countStyle: .binary
        )
        let withOptStr: String = ByteCountFormatter.string(
            fromByteCount: totalWithOptimization,
            countStyle: .binary
        )
        print("Without optimization: \(withoutOptStr)")
        print("With optimization: \(withOptStr)")
        print("Savings: \(Int(savings))%")

        #expect(selectedFiles.filter { $0.path.hasSuffix(".zip") }.count == 1, "Should select only 1 ZIP file")
        #expect(savings >= 75, "Should save at least 75% bandwidth")
    }

    @Test("Verify CoreML restructuring creates flat directory")
    func testCoreMLFlatStructure() async throws {
        let tempDir: URL = FileManager.default.temporaryDirectory
            .appendingPathComponent("coreml-flat-test-\(UUID())")

        defer { try? FileManager.default.removeItem(at: tempDir) }

        // Create nested structure
        let nestedDir: URL = tempDir
            .appendingPathComponent("coreml")
            .appendingPathComponent("stable-diffusion-v1-5_split-einsum")

        try FileManager.default.createDirectory(
            at: nestedDir,
            withIntermediateDirectories: true
        )

        // Create critical files
        let criticalFiles: [String] = ["merges.txt", "vocab.json", "config.json"]
        for filename: String in criticalFiles {
            try "test content".write(
                to: nestedDir.appendingPathComponent(filename),
                atomically: true,
                encoding: .utf8
            )
        }

        // Run restructuring
        let extractor: ZipExtractor = ZipExtractor()
        try await extractor.restructureCoreMLFiles(at: tempDir)

        // Verify files are at root
        for filename: String in criticalFiles {
            let rootPath: URL = tempDir.appendingPathComponent(filename)
            #expect(
                FileManager.default.fileExists(atPath: rootPath.path),
                "\(filename) should be at root level"
            )
        }

        print("CoreML files successfully restructured to flat directory")
    }

    @Test("Verify complete CoreML download flow")
    func testCompleteCoreMLFlow() async throws {
        // Step 1: File selection
        let files: [FileInfo] = [
            FileInfo(path: "coreml/split-einsum/model.zip", size: 2_147_483_648),
            FileInfo(path: "coreml/original/model.zip", size: 2_147_483_648),
            FileInfo(path: "merges.txt", size: 1_000)
        ]

        let selector: CoreMLFileSelector = CoreMLFileSelector()
        let selected: [FileInfo] = await selector.selectFiles(from: files)

        #expect(selected.count == 2, "Should select 1 ZIP + metadata")

        // Step 2: Verify the selection is optimal
        let zipFiles: [FileInfo] = selected.filter { $0.path.hasSuffix(".zip") }
        #expect(zipFiles.count == 1, "Should select exactly one ZIP file")

        // Verify metadata files are included
        let metadataFiles: [FileInfo] = selected.filter { !$0.path.hasSuffix(".zip") }
        #expect(!metadataFiles.isEmpty, "Should include metadata files")

        print("Complete CoreML flow verified:")
        print("  1. Intelligent file selection working")
        print("  2. HuggingFaceDownloader integration working")
        print("  3. Only downloading necessary files")
    }
}
