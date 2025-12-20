import Abstractions
@testable import ModelDownloader
import Testing

@Suite("BackendDetector Tests")
struct BackendDetectorTests {
    @Test("Detect MLX backend from files")
    func testMLXDetection() async {
        let detector: BackendDetector = BackendDetector()

        // Valid MLX model files
        let mlxFiles: [ModelFile] = [
            ModelFile(path: "model.safetensors", size: 1_000_000_000),
            ModelFile(path: "config.json", size: 1_024),
            ModelFile(path: "tokenizer.json", size: 2_048)
        ]

        let backends: [SendableModel.Backend] = await detector.detectBackends(from: mlxFiles)
        #expect(backends.contains(.mlx))
        #expect(backends.count == 1)
    }

    @Test("Detect GGUF backend from files")
    func testGGUFDetection() async {
        let detector: BackendDetector = BackendDetector()

        // GGUF model files
        let ggufFiles: [ModelFile] = [
            ModelFile(path: "llama-2-7b-chat.Q4_K_M.gguf", size: 4_000_000_000),
            ModelFile(path: "README.md", size: 1_024)
        ]

        let backends: [SendableModel.Backend] = await detector.detectBackends(from: ggufFiles)
        #expect(backends.contains(.gguf))
        #expect(backends.count == 1)
    }

    @Test("Detect CoreML backend from files")
    func testCoreMLDetection() async {
        let detector: BackendDetector = BackendDetector()

        // Test .mlpackage files
        let mlpackageFiles: [ModelFile] = [
            ModelFile(path: "model.mlpackage", size: 500_000_000),
            ModelFile(path: "README.md", size: 1_024)
        ]

        var backends: [SendableModel.Backend] = await detector.detectBackends(from: mlpackageFiles)
        #expect(backends.contains(.coreml))

        // Test .mlmodel files
        let mlmodelFiles: [ModelFile] = [
            ModelFile(path: "model.mlmodel", size: 300_000_000),
            ModelFile(path: "config.json", size: 1_024)
        ]

        backends = await detector.detectBackends(from: mlmodelFiles)
        #expect(backends.contains(.coreml))

        // Test CoreML in zip with proper naming convention
        let zipFiles: [ModelFile] = [
            ModelFile(path: "split_einsum/model.mlmodelc.zip", size: 400_000_000),
            ModelFile(path: "info.plist", size: 512)
        ]

        backends = await detector.detectBackends(from: zipFiles)
        #expect(backends.contains(.coreml))
    }

    @Test("Detect multiple backends")
    func testMultipleBackendDetection() async {
        let detector: BackendDetector = BackendDetector()

        // Model with both MLX and GGUF files
        let multiBackendFiles: [ModelFile] = [
            ModelFile(path: "model.safetensors", size: 1_000_000_000),
            ModelFile(path: "config.json", size: 1_024),
            ModelFile(path: "model-q4.gguf", size: 800_000_000),
            ModelFile(path: "README.md", size: 2_048)
        ]

        let backends: [SendableModel.Backend] = await detector.detectBackends(from: multiBackendFiles)
        #expect(backends.contains(.mlx))
        #expect(backends.contains(.gguf))
        #expect(backends.count == 2)

        // Verify sorting
        #expect(backends == [.gguf, .mlx]) // Alphabetical order
    }

    @Test("No backend detection for invalid files")
    func testNoBackendDetection() async {
        let detector: BackendDetector = BackendDetector()

        // No model files
        let nonModelFiles: [ModelFile] = [
            ModelFile(path: "README.md", size: 1_024),
            ModelFile(path: "LICENSE", size: 512),
            ModelFile(path: ".gitignore", size: 128)
        ]

        let backends: [SendableModel.Backend] = await detector.detectBackends(from: nonModelFiles)
        #expect(backends.isEmpty)
    }

    @Test("MLX requires both safetensors and config")
    func testMLXRequirements() async {
        let detector: BackendDetector = BackendDetector()

        // Only safetensors, no config
        let onlySafetensors: [ModelFile] = [
            ModelFile(path: "model.safetensors", size: 1_000_000_000)
        ]

        var backends: [SendableModel.Backend] = await detector.detectBackends(from: onlySafetensors)
        #expect(!backends.contains(.mlx))

        // Only config, no safetensors
        let onlyConfig: [ModelFile] = [
            ModelFile(path: "config.json", size: 1_024)
        ]

        backends = await detector.detectBackends(from: onlyConfig)
        #expect(!backends.contains(.mlx))
    }

    @Test("Analyze single file")
    func testAnalyzeSingleFile() async {
        let detector: BackendDetector = BackendDetector()

        // Test various file types
        var backends: [SendableModel.Backend] = await detector.analyzeFile(ModelFile(path: "model.safetensors"))
        #expect(backends.contains(.mlx))

        backends = await detector.analyzeFile(ModelFile(path: "model.gguf"))
        #expect(backends.contains(.gguf))

        backends = await detector.analyzeFile(ModelFile(path: "model.mlpackage"))
        #expect(backends.contains(.coreml))

        backends = await detector.analyzeFile(ModelFile(path: "coreml-model.zip"))
        #expect(backends.contains(.coreml))

        backends = await detector.analyzeFile(ModelFile(path: "README.md"))
        #expect(backends.isEmpty)
    }

    @Test("Case insensitive detection")
    func testCaseInsensitiveDetection() async {
        let detector: BackendDetector = BackendDetector()

        let mixedCaseFiles: [ModelFile] = [
            ModelFile(path: "Model.SAFETENSORS", size: 1_000_000_000),
            ModelFile(path: "Config.JSON", size: 1_024),
            ModelFile(path: "model.GGUF", size: 800_000_000),
            ModelFile(path: "Model.MLPackage", size: 500_000_000)
        ]

        let backends: [SendableModel.Backend] = await detector.detectBackends(from: mixedCaseFiles)
        #expect(backends.contains(.mlx))
        #expect(backends.contains(.gguf))
        #expect(backends.contains(.coreml))
    }
}
