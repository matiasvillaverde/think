@testable import ModelDownloader
import Testing

@Suite("CoreML File Selector Tests")
internal struct CoreMLFileSelectorTests {
    @Test("Select optimal ZIP file from subdirectories")
    func testSelectOptimalZipFromSubdirectories() async {
        let selector: CoreMLFileSelector = CoreMLFileSelector()

        // Mock files representing typical CoreML repository structure
        let files: [FileInfo] = [
            FileInfo(path: "original/crystalClearXL_original_SDXL_8-bit.zip", size: 2_500_000_000),
            FileInfo(path: "split-einsum/768x768/animagine-xl-3.1_split-einsum_6bit_768x768.zip", size: 1_200_000_000),
            FileInfo(
                path: "split-einsum/1024x1024/animagine-xl-3.1_split-einsum_6bit_1024x1024.zip",
                size: 1_800_000_000
            ),
            FileInfo(path: "config.json", size: 1_024),
            FileInfo(path: "README.md", size: 2_048)
        ]

        let selectedFiles: [FileInfo] = await selector.selectFiles(from: files)

        #expect(!selectedFiles.isEmpty, "Should select files")

        // Should prefer split-einsum over original
        let zipFile: FileInfo? = selectedFiles.first { $0.path.hasSuffix(".zip") }
        #expect(zipFile != nil, "Should select a ZIP file")
        #expect(zipFile?.path.contains("split-einsum") == true, "Should prefer split-einsum variant")

        // Should include metadata files
        let hasConfig: Bool = selectedFiles.contains { $0.path == "config.json" }
        #expect(hasConfig, "Should include config.json")
    }

    @Test("Select compiled format for Swift usage")
    func testSelectCompiledFormat() async {
        let selector: CoreMLFileSelector = CoreMLFileSelector()

        let files: [FileInfo] = [
            FileInfo(path: "original/compiled/Stable_Diffusion_v1_5_palettized_8-bit.mlmodelc.zip", size: 800_000_000),
            FileInfo(path: "original/packages/Stable_Diffusion_v1_5.mlpackage", size: 900_000_000),
            FileInfo(path: "split_einsum/compiled/Unet_split_einsum_compiled.mlmodelc.zip", size: 600_000_000),
            FileInfo(path: "split_einsum/packages/Unet_split_einsum.mlpackage", size: 700_000_000),
            FileInfo(path: "merges.txt", size: 500_000),
            FileInfo(path: "vocab.json", size: 800_000)
        ]

        let selectedFiles: [FileInfo] = await selector.selectFiles(from: files)

        // Should select compiled format over packages
        let compiledFiles: [FileInfo] = selectedFiles.filter { $0.path.contains("compiled") }
        let packageFiles: [FileInfo] = selectedFiles.filter { $0.path.contains("packages") }

        #expect(!compiledFiles.isEmpty, "Should select compiled files")
        #expect(packageFiles.isEmpty, "Should not select package files when compiled available")

        // Should prefer split_einsum
        let splitEinsum: FileInfo? = compiledFiles.first { $0.path.contains("split_einsum") }
        #expect(splitEinsum != nil, "Should prefer split_einsum variant")
    }

    @Test("Handle multiple ZIP files in same variant - select only one")
    func testMultipleZipSelection() async {
        let selector: CoreMLFileSelector = CoreMLFileSelector()

        let files: [FileInfo] = [
            FileInfo(path: "split_einsum/compiled/VAEDecoder_split_einsum_compiled.mlmodelc.zip", size: 200_000_000),
            FileInfo(path: "split_einsum/compiled/VAEEncoder_split_einsum_compiled.mlmodelc.zip", size: 150_000_000),
            FileInfo(path: "split_einsum/compiled/Unet_split_einsum_compiled.mlmodelc.zip", size: 600_000_000),
            FileInfo(path: "split_einsum/compiled/TextEncoder_split_einsum_compiled.mlmodelc.zip", size: 300_000_000)
        ]

        let selectedFiles: [FileInfo] = await selector.selectFiles(from: files)

        // Should select only ONE ZIP file from the preferred variant
        let zipFiles: [FileInfo] = selectedFiles.filter { $0.path.hasSuffix(".zip") }
        #expect(zipFiles.count == 1, "Should select only one ZIP file, but got \(zipFiles.count)")
        #expect(zipFiles.first?.path.contains("split_einsum") == true,
               "Selected file should be from split_einsum variant")
    }

    @Test("Handle legacy root-level files")
    func testLegacyRootLevelFiles() async {
        let selector: CoreMLFileSelector = CoreMLFileSelector()

        let files: [FileInfo] = [
            FileInfo(path: "model.mlmodel", size: 500_000_000),
            FileInfo(path: "model.mlpackage", size: 600_000_000),
            FileInfo(path: "config.json", size: 1_024)
        ]

        let selectedFiles: [FileInfo] = await selector.selectFiles(from: files)

        #expect(!selectedFiles.isEmpty, "Should handle root-level files")

        // Should prefer mlmodel over mlpackage for backward compatibility
        let mlmodelFile: FileInfo? = selectedFiles.first { $0.path.hasSuffix(".mlmodel") }
        #expect(mlmodelFile != nil, "Should select .mlmodel file")

        let hasConfig: Bool = selectedFiles.contains { $0.path == "config.json" }
        #expect(hasConfig, "Should include config.json")
    }

    @Test("Include essential metadata files")
    func testMetadataInclusion() async {
        let selector: CoreMLFileSelector = CoreMLFileSelector()

        let files: [FileInfo] = [
            FileInfo(path: "split_einsum/compiled/model.mlmodelc.zip", size: 600_000_000),
            FileInfo(path: "config.json", size: 1_024),
            FileInfo(path: "tokenizer.json", size: 2_048),
            FileInfo(path: "merges.txt", size: 512),
            FileInfo(path: "vocab.json", size: 768),
            FileInfo(path: "model_index.json", size: 256),
            FileInfo(path: "README.md", size: 4_096),
            FileInfo(path: "LICENSE", size: 1_024)
        ]

        let selectedFiles: [FileInfo] = await selector.selectFiles(from: files)

        // Should include all essential metadata
        let expectedMetadata: [String] = [
            "config.json", "tokenizer.json", "merges.txt", "vocab.json", "model_index.json"
        ]
        for metadata in expectedMetadata {
            let hasFile: Bool = selectedFiles.contains { $0.path == metadata }
            #expect(hasFile, "Should include \(metadata)")
        }

        // Should exclude non-essential files
        let hasReadme: Bool = selectedFiles.contains { $0.path == "README.md" }
        let hasLicense: Bool = selectedFiles.contains { $0.path == "LICENSE" }
        #expect(!hasReadme && !hasLicense, "Should exclude non-essential files")
    }

    @Test("Handle empty file list")
    func testEmptyFileList() async {
        let selector: CoreMLFileSelector = CoreMLFileSelector()

        let selectedFiles: [FileInfo] = await selector.selectFiles(from: [])

        #expect(selectedFiles.isEmpty, "Should return empty array for empty: Any input")
    }

    @Test("Handle files with no CoreML models")
    func testNoCoreMLFiles() async {
        let selector: CoreMLFileSelector = CoreMLFileSelector()

        let files: [FileInfo] = [
            FileInfo(path: "README.md", size: 2_048),
            FileInfo(path: ".gitignore", size: 256),
            FileInfo(path: "requirements.txt", size: 512)
        ]

        let selectedFiles: [FileInfo] = await selector.selectFiles(from: files)

        #expect(selectedFiles.isEmpty, "Should return empty array when no CoreML files present")
    }

    @Test("Prefer original when split_einsum not available")
    func testFallbackToOriginal() async {
        let selector: CoreMLFileSelector = CoreMLFileSelector()

        let files: [FileInfo] = [
            FileInfo(path: "original/compiled/model.mlmodelc.zip", size: 800_000_000),
            FileInfo(path: "original/packages/model.mlpackage", size: 900_000_000),
            FileInfo(path: "config.json", size: 1_024)
        ]

        let selectedFiles: [FileInfo] = await selector.selectFiles(from: files)

        let zipFile: FileInfo? = selectedFiles.first { $0.path.hasSuffix(".zip") }
        #expect(zipFile != nil, "Should select available variant")
        #expect(zipFile?.path.contains("original") == true, "Should use original when split_einsum not available")
    }

    @Test("Select single ZIP for coreml-stable-diffusion repository")
    func testCoreMLStableDiffusionRepoStructure() async {
        let selector: CoreMLFileSelector = CoreMLFileSelector()

        // Actual structure from coreml-community/coreml-stable-diffusion-v1-5
        let files: [FileInfo] = [
            // Split-einsum variant (should be selected)
            FileInfo(path: "split-einsum/v1-5_split-einsum.zip", size: 2_070_000_000),

            // Original variant (should NOT be selected)
            FileInfo(path: "original/v1-5_original.zip", size: 3_000_000_000),

            // Metadata files (should be selected)
            FileInfo(path: "config.json", size: 500),
            FileInfo(path: "merges.txt", size: 500_000),
            FileInfo(path: "tokenizer.json", size: 2_000),
            FileInfo(path: "vocab.json", size: 1_000),

            // Other files (should NOT be selected)
            FileInfo(path: "README.md", size: 5_000),
            FileInfo(path: ".gitignore", size: 100)
        ]

        let selectedFiles: [FileInfo] = await selector.selectFiles(from: files)
        let selectedPaths: [String] = selectedFiles.map(\.path)

        // Should select only ONE ZIP file
        let zipFiles: [String] = selectedPaths.filter { $0.hasSuffix(".zip") }
        #expect(zipFiles.count == 1, "Should select exactly one ZIP file")
        #expect(zipFiles.first == "split-einsum/v1-5_split-einsum.zip",
               "Should select the split-einsum ZIP file")

        // Should include essential metadata
        #expect(selectedPaths.contains("config.json"))
        #expect(selectedPaths.contains("merges.txt"))
        #expect(selectedPaths.contains("tokenizer.json"))
        #expect(selectedPaths.contains("vocab.json"))

        // Should NOT include README or other files
        #expect(!selectedPaths.contains("README.md"))
        #expect(!selectedPaths.contains(".gitignore"))
    }

    @Test("Handle mixed subdirectory and root files")
    func testMixedFileStructure() async {
        let selector: CoreMLFileSelector = CoreMLFileSelector()

        let files: [FileInfo] = [
            FileInfo(path: "model.mlmodel", size: 300_000_000),
            FileInfo(path: "split_einsum/compiled/better_model.mlmodelc.zip", size: 400_000_000),
            FileInfo(path: "config.json", size: 1_024)
        ]

        let selectedFiles: [FileInfo] = await selector.selectFiles(from: files)

        // Should prefer subdirectory structure over root
        let selectedModel: FileInfo? = selectedFiles.first { $0.path.contains(".mlmodel") || $0.path.contains(".zip") }
        #expect(selectedModel?.path.contains("split_einsum") == true, "Should prefer subdirectory model over root")
    }
}
