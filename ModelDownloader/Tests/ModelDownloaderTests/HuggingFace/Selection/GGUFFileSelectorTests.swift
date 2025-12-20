@testable import ModelDownloader
import Testing

@Suite("GGUF File Selector Tests")
internal struct GGUFFileSelectorTests {
    @Test("Select optimal file based on device memory - high memory device")
    func testOptimalSelectionHighMemory() async {
        let selector: GGUFFileSelector = GGUFFileSelector()

        // Mock files representing different quantization levels
        let files: [FileInfo] = [
            FileInfo(path: "model-iq3_m.gguf", size: 1_600_000_000),      // 1.6GB - smallest
            FileInfo(path: "model-iq4_xs.gguf", size: 1_830_000_000),     // 1.83GB
            FileInfo(path: "model-q4_0.gguf", size: 1_920_000_000),       // 1.92GB 
            FileInfo(path: "model-q4_k_m.gguf", size: 2_020_000_000),     // 2.02GB
            FileInfo(path: "model-q5_k_m.gguf", size: 2_320_000_000),     // 2.32GB
            FileInfo(path: "model-q6_k.gguf", size: 2_640_000_000),       // 2.64GB - high quality
            FileInfo(path: "model-q8_0.gguf", size: 3_420_000_000),       // 3.42GB - highest quality
            FileInfo(path: "config.json", size: 1_024)                     // metadata
        ]

        let selectedFile: FileInfo? = await selector.selectOptimalFile(from: files)

        #expect(selectedFile != nil, "Should select a file")

        // On high-memory devices, should prefer quality (q6_k or q8_0)
        let selectedName: String = selectedFile?.path ?? ""
        #expect(
            selectedName.contains("q6_k") || selectedName.contains("q8_0") || selectedName.contains("q5_k_m"),
            "High memory device should prefer high quality quantization, got: \(selectedName)"
        )
    }

    @Test("Select specified filename when provided")
    func testSpecificFileSelection() async {
        let selector: GGUFFileSelector = GGUFFileSelector()

        let files: [FileInfo] = [
            FileInfo(path: "model-iq3_m.gguf", size: 1_600_000_000),
            FileInfo(path: "model-q4_k_m.gguf", size: 2_020_000_000),
            FileInfo(path: "model-q6_k.gguf", size: 2_640_000_000),
            FileInfo(path: "config.json", size: 1_024)
        ]

        let selectedFile: FileInfo? = await selector.selectOptimalFile(
            from: files,
            specifiedFilename: "q4_k_m"
        )

        #expect(selectedFile != nil, "Should find the specified file")
        #expect(selectedFile?.path.contains("q4_k_m") == true, "Should select the Q4_K_M variant")
    }

    @Test("Handle case when specified file not found")
    func testSpecificFileNotFound() async {
        let selector: GGUFFileSelector = GGUFFileSelector()

        let files: [FileInfo] = [
            FileInfo(path: "model-iq3_m.gguf", size: 1_600_000_000),
            FileInfo(path: "model-q4_k_m.gguf", size: 2_020_000_000),
            FileInfo(path: "config.json", size: 1_024)
        ]

        let selectedFile: FileInfo? = await selector.selectOptimalFile(
            from: files,
            specifiedFilename: "nonexistent-variant"
        )

        #expect(selectedFile == nil, "Should return nil when specified file not found")
    }

    @Test("Handle empty file list")
    func testEmptyFileList() async {
        let selector: GGUFFileSelector = GGUFFileSelector()

        let selectedFile: FileInfo? = await selector.selectOptimalFile(from: [])

        #expect(selectedFile == nil, "Should return nil for empty file list")
    }

    @Test("Handle files with no GGUF files")
    func testNoGGUFFiles() async {
        let selector: GGUFFileSelector = GGUFFileSelector()

        let files: [FileInfo] = [
            FileInfo(path: "config.json", size: 1_024),
            FileInfo(path: "tokenizer.json", size: 2_048),
            FileInfo(path: "README.md", size: 512)
        ]

        let selectedFile: FileInfo? = await selector.selectOptimalFile(from: files)

        #expect(selectedFile == nil, "Should return nil when no GGUF files present")
    }

    @Test("Select best available when preferred quantization not available")
    func testFallbackSelection() async {
        let selector: GGUFFileSelector = GGUFFileSelector()

        // Only provide lower-quality options
        let files: [FileInfo] = [
            FileInfo(path: "model-iq3_m.gguf", size: 1_600_000_000),
            FileInfo(path: "model-iq4_xs.gguf", size: 1_830_000_000),
            FileInfo(path: "config.json", size: 1_024)
        ]

        let selectedFile: FileInfo? = await selector.selectOptimalFile(from: files)

        #expect(selectedFile != nil, "Should select the best available option")

        // Should prefer iq4_xs over iq3_m when no high-quality options available
        let selectedName: String = selectedFile?.path ?? ""
        #expect(
            selectedName.contains("iq4_xs") || selectedName.contains("iq3_m"),
            "Should select one of the available quantizations"
        )
    }

    @Test("Quantization type parsing accuracy")
    func testQuantizationTypeParsing() async {
        let selector: GGUFFileSelector = GGUFFileSelector()

        let testCases: [(String, String)] = [
            ("model-f16.gguf", "f16"),
            ("model-q8_0.gguf", "q8"),
            ("model-q6_k.gguf", "q6"),
            ("model-q5_k_m.gguf", "q5"),
            ("model-q4_k_m.gguf", "q4_k"),
            ("model-q4_0.gguf", "q4_0"),
            ("model-iq4_xs.gguf", "iq4"),
            ("model-iq3_m.gguf", "iq3")
        ]

        for (filename, _) in testCases {
            let files: [FileInfo] = [FileInfo(path: filename, size: 1_000_000_000)]
            let selectedFile: FileInfo? = await selector.selectOptimalFile(from: files)

            #expect(selectedFile != nil, "Should parse and select file: \(filename)")
            #expect(selectedFile?.path == filename, "Should select the correct file: \(filename)")
        }
    }
}

// MARK: - Helper Extensions

extension FileInfo {
    /// Convenience initializer for tests
    init(path: String, size: Int64) {
        self.init(
            path: path,
            size: size,
            lfs: nil
        )
    }
}
