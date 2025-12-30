import Abstractions
import Foundation
@testable import ModelDownloader
import Testing
#if canImport(Darwin)
import Darwin
#else
import Glibc
#endif

// MARK: - Model Format Integration Tests
// These tests verify the download flow for each model format using mocks

// Progress collector to handle concurrent updates
private actor ProgressCollector {
    private var updates: [Double] = []

    func add(_ progress: Double) {
        updates.append(progress)
    }

    var values: [Double] {
        updates
    }

    var isEmpty: Bool {
        updates.isEmpty
    }

    var last: Double? {
        updates.last
    }
}

@Test("MLX model file tracking")
internal func testMLXModelFileTracking() async {
    // Setup mock file manager
    let mockFileManager: MockFileManager = MockFileManager()
    let backend: SendableModel.Backend = SendableModel.Backend.mlx

    // Simulate downloading MLX files
    let mlxFiles: [String] = [
        "config.json",
        "model.safetensors",
        "tokenizer.json"
    ]

    // Track files in mock
    for file in mlxFiles {
        mockFileManager.addDownloadedFile(file)
    }

    // Simulate finalize download
    let repositoryId: String = "test-org/test-mlx-model"
    let modelInfo: ModelInfo = await mockFileManager.finalizeDownload(
        repositoryId: repositoryId,
        name: "test-org/test-mlx-model",
        backend: backend,
        from: URL(fileURLWithPath: "/tmp/test"),
        totalSize: 1_000
    )

    // Verify results
    #expect(modelInfo.name == "test-org/test-mlx-model")
    #expect(modelInfo.backend == SendableModel.Backend.mlx)

    // Verify MLX-specific files were tracked correctly
    let downloadedFiles: Set<String> = Set(mockFileManager.downloadedFiles)
    #expect(downloadedFiles.contains("config.json"))
    #expect(downloadedFiles.contains("model.safetensors"))
    #expect(downloadedFiles.contains("tokenizer.json"))
}

@Test("CoreML model file tracking")
internal func testCoreMLModelFileTracking() async {
    // Setup mock file manager
    let mockFileManager: MockFileManager = MockFileManager()
    let backend: SendableModel.Backend = SendableModel.Backend.coreml

    // Simulate downloading CoreML files
    let coremlFiles: [String] = [
        "TextEncoder.mlpackage/Data/com.apple.CoreML/model.mlmodel",
        "TextEncoder.mlpackage/Data/com.apple.CoreML/weights.bin",
        "TextEncoder.mlpackage/Manifest.json"
    ]

    // Track files in mock
    for file: String in coremlFiles {
        mockFileManager.addDownloadedFile(file)
    }

    // Simulate finalize download
    let repositoryId: String = "test-org/test-coreml-model"
    let modelInfo: ModelInfo = await mockFileManager.finalizeDownload(
        repositoryId: repositoryId,
        name: "test-org/test-coreml-model",
        backend: backend,
        from: URL(fileURLWithPath: "/tmp/test"),
        totalSize: 1_000
    )

    // Verify results
    #expect(modelInfo.name == "test-org/test-coreml-model")
    #expect(modelInfo.backend == SendableModel.Backend.coreml)

    // Verify CoreML-specific files were tracked correctly
    let downloadedFiles: Set<String> = Set(mockFileManager.downloadedFiles)
    #expect(downloadedFiles.contains { $0.contains(".mlpackage") })
}

@Test("GGUF model file tracking")
internal func testGGUFModelFileTracking() async {
    // Setup mock file manager
    let mockFileManager: MockFileManager = MockFileManager()
    let backend: SendableModel.Backend = SendableModel.Backend.gguf

    // Simulate downloading GGUF files
    let ggufFiles: [String] = [
        "model-q4_0.gguf",
        "tokenizer.json"
    ]

    // Track files in mock
    for file in ggufFiles {
        mockFileManager.addDownloadedFile(file)
    }

    // Simulate finalize download
    let repositoryId: String = "test-org/test-gguf-model"
    let modelInfo: ModelInfo = await mockFileManager.finalizeDownload(
        repositoryId: repositoryId,
        name: "test-org/test-gguf-model",
        backend: backend,
        from: URL(fileURLWithPath: "/tmp/test"),
        totalSize: 1_000
    )

    // Verify results
    #expect(modelInfo.name == "test-org/test-gguf-model")
    #expect(modelInfo.backend == SendableModel.Backend.gguf)

    // Verify GGUF files were tracked correctly
    let downloadedFiles: Set<String> = Set(mockFileManager.downloadedFiles)
    let ggufFileCount: Int = downloadedFiles.filter { $0.contains(".gguf") }.count
    #expect(ggufFileCount > 0, "Should have tracked at least one GGUF file")
}

@Test("Multi-format model file tracking")
internal func testMultiFormatModelFileTracking() async {
    // Setup mock file manager
    let mockFileManager: MockFileManager = MockFileManager()

    // Test MLX format
    mockFileManager.addDownloadedFile("mlx/config.json")
    mockFileManager.addDownloadedFile("mlx/model.safetensors")

    let mlxRepositoryId: String = "test-org/multi-format-model-mlx"
    let mlxInfo: ModelInfo = await mockFileManager.finalizeDownload(
        repositoryId: mlxRepositoryId,
        name: "test-org/multi-format-model",
        backend: SendableModel.Backend.mlx,
        from: URL(fileURLWithPath: "/tmp/test"),
        totalSize: 1_000
    )

    #expect(mlxInfo.backend == SendableModel.Backend.mlx)

    // Reset for GGUF format
    mockFileManager.reset()
    mockFileManager.addDownloadedFile("gguf/model-q4_0.gguf")

    let ggufRepositoryId: String = "test-org/multi-format-model-gguf"
    let ggufInfo: ModelInfo = await mockFileManager.finalizeDownload(
        repositoryId: ggufRepositoryId,
        name: "test-org/multi-format-model",
        backend: SendableModel.Backend.gguf,
        from: URL(fileURLWithPath: "/tmp/test"),
        totalSize: 1_000
    )

    #expect(ggufInfo.backend == SendableModel.Backend.gguf)
}
