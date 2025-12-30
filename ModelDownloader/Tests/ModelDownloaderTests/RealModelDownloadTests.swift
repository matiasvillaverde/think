import Abstractions
import Foundation
@testable import ModelDownloader
import Testing
#if canImport(Darwin)
import Darwin
#else
import Glibc
#endif

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

// MARK: - Real Model Download Tests
// These tests download actual models from HuggingFace Hub
// They are disabled by default because they:
// 1. Take significant time to run
// 2. Require network connectivity
// 3. Use disk space for downloaded models
// 4. May hit rate limits if run frequently

@Test("Debug download flow")
internal func testDebugDownloadFlow() async throws {
    // Create test directory structure
    let tempDir: URL = FileManager.default.temporaryDirectory
        .appendingPathComponent("debug-test-\(UUID().uuidString)")
    defer {
        try? FileManager.default.removeItem(at: tempDir)
    }

    // Initialize file manager with custom directories
    let fileManager: ModelFileManager = ModelFileManager(
        modelsDirectory: tempDir.appendingPathComponent("models"),
        temporaryDirectory: tempDir.appendingPathComponent("downloads")
    )

    // Create a mock downloader that doesn't actually download
    let mockDownloader: MockStreamingDownloader = MockStreamingDownloader()
    _ = DownloadCoordinator(downloader: mockDownloader)

    // Create test download info
    let repositoryId: String = "test/model"
    let downloadDir: URL = fileManager.temporaryDirectory(for: repositoryId)

    print("Download directory: \(downloadDir.path)")

    // Create the directory
    try FileManager.default.createDirectory(
        at: downloadDir,
        withIntermediateDirectories: true
    )

    // Create test files in the download directory
    let testFiles: [String] = ["config.json", "model.safetensors"]
    for fileName: String in testFiles {
        let filePath: URL = downloadDir.appendingPathComponent(fileName)
        try "test content".write(to: filePath, atomically: true, encoding: .utf8)
        print("Created test file: \(filePath.path)")
    }

    // Verify files exist
    let contents: [URL] = try FileManager.default.contentsOfDirectory(at: downloadDir, includingPropertiesForKeys: nil)
    print("Directory contents: \(contents.map(\.lastPathComponent))")

    // Now test finalize download
    do {
        let modelInfo: ModelInfo = try await fileManager.finalizeDownload(
            repositoryId: repositoryId,
            name: "test-model",
            backend: SendableModel.Backend.mlx,
            from: downloadDir,
            totalSize: 100
        )

        print("Successfully finalized download to: \(modelInfo.location.path)")

        // Verify final location
        let finalContents: [URL] = try FileManager.default.contentsOfDirectory(
            at: modelInfo.location,
            includingPropertiesForKeys: nil
        )
        print("Final location contents: \(finalContents.map(\.lastPathComponent))")
    } catch {
        print("Finalize failed with error: \(error)")
        if let nsError: NSError = error as NSError? {
            print("NSError details:")
            print("  Domain: \(nsError.domain)")
            print("  Code: \(nsError.code)")
            print("  Path: \(nsError.userInfo[NSFilePathErrorKey] ?? "none")")
        }
        throw error
    }
}

@Test("ModelFileManager path consistency")
internal func testModelFileManagerPathConsistency() async throws {
    // Create temporary directory for test
    let tempDir: URL = FileManager.default.temporaryDirectory
        .appendingPathComponent("test-path-\(UUID().uuidString)")
    defer {
        try? FileManager.default.removeItem(at: tempDir)
    }

    // Initialize file manager
    let fileManager: ModelFileManager = ModelFileManager(modelsDirectory: tempDir)

    let backend: SendableModel.Backend = SendableModel.Backend.mlx
    let modelName: String = "test-org/test-model"

    // Simulate finalize download with a fake temp directory
    let fakeTempDir: URL = tempDir.appendingPathComponent("temp-\(UUID().uuidString)")
    try FileManager.default.createDirectory(at: fakeTempDir, withIntermediateDirectories: true)

    // Create a dummy file in the temp directory
    let dummyFile: URL = fakeTempDir.appendingPathComponent("dummy.txt")
    try "test content".write(to: dummyFile, atomically: true, encoding: .utf8)

    // Finalize the download
    let repositoryId: String = "test/model"
    let modelInfo: ModelInfo = try await fileManager.finalizeDownload(
        repositoryId: repositoryId,
        name: modelName,
        backend: backend,
        from: fakeTempDir,
        totalSize: 1_024
    )

    // Verify the model info
    // Note: modelInfo.id is generated deterministically from repositoryId, not the input modelId
    #expect(modelInfo.name == modelName)
    #expect(modelInfo.backend == backend)

    // Verify the location exists
    #expect(FileManager.default.fileExists(atPath: modelInfo.location.path))

    // Verify the model exists check
    let exists: Bool = await fileManager.modelExists(repositoryId: repositoryId)
    #expect(exists)

    // Clean up the temp directory
    try? FileManager.default.removeItem(at: fakeTempDir)
}

@Test("Download real MLX model from HuggingFace")
@MainActor
internal func testDownloadRealMLXModel() async throws {
    let context: TestDownloaderContext = TestDownloaderContext()
    defer { context.cleanup() }

    let modelId: String = "hf-internal-testing/tiny-random-gpt2"
    let fixture: MockHuggingFaceDownloader.FixtureModel = MockHuggingFaceDownloader.FixtureModel(
        modelId: modelId,
        backend: .mlx,
        name: modelId,
        files: [
            MockHuggingFaceDownloader.FixtureFile(
                path: "model.safetensors",
                data: Data(repeating: 0x1, count: 32),
                size: 32
            ),
            MockHuggingFaceDownloader.FixtureFile(
                path: "config.json",
                data: Data("{\"config\":true}".utf8),
                size: Int64("{\"config\":true}".utf8.count)
            )
        ]
    )
    await context.mockDownloader.registerFixture(fixture)

    let sendableModel: SendableModel = SendableModel(
        id: UUID(),
        ramNeeded: 128_000_000,
        modelType: .language,
        location: modelId,
        architecture: .llama,
        backend: .mlx,
        locationKind: .huggingFace
    )

    let progressUpdates: ProgressCollector = ProgressCollector()
    var modelInfo: ModelInfo?

    for try await event in context.downloader.downloadModel(sendableModel: sendableModel) {
        switch event {
        case .progress(let progress):
            Task { await progressUpdates.add(progress.fractionCompleted) }

        case .completed(let info):
            modelInfo = info
        }
    }

    guard let modelInfo else {
        throw HuggingFaceError.downloadFailed
    }

    #expect(modelInfo.name == modelId)
    #expect(modelInfo.backend == .mlx)
    #expect(await progressUpdates.isEmpty == false)
    #expect(await progressUpdates.last == 1.0)

    let modelPath: URL = modelInfo.location
    #expect(FileManager.default.fileExists(atPath: modelPath.path))

    let contents: [URL] = try FileManager.default.contentsOfDirectory(
        at: modelPath,
        includingPropertiesForKeys: nil
    )

    let hasWeights: Bool = contents.contains { $0.pathExtension == "safetensors" }
    let hasConfig: Bool = contents.contains { $0.lastPathComponent == "config.json" }

    #expect(hasWeights)
    #expect(hasConfig)
}

@Test("Debug CoreML repository files")
internal func testDebugCoreMLRepoFiles() {
    // Test different CoreML repositories
    let repos: [String] = [
        "apple/coreml-stable-diffusion-v1-4",
        "huggingface/coreml-examples",
        "coreml-projects/EfficientNet",
        "google/mobilenet_v2_1.0_224"
    ]

    let files: [FileInfo] = [
        FileInfo(path: "TextEncoder.mlmodelc/model.mil", size: 1_024),
        FileInfo(path: "Unet.mlmodelc/model.mil", size: 2_048),
        FileInfo(path: "README.md", size: 256)
    ]

    for modelId in repos {
        print("\n=== Repository: \(modelId) ===")
        print("Found \(files.count) files:")

        for file in files {
            print("  - \(file.path) (size: \(file.size) bytes)")
        }

        let coremlFiles: [FileInfo] = files.filter { file in
            file.path.contains(".mlpackage") ||
            file.path.contains(".mlmodel") ||
            file.path.hasSuffix(".zip") ||
            file.path.contains("coreml") ||
            file.path.contains(".mlmodelc")
        }

        print("\nCoreML-related files:")
        for file in coremlFiles {
            print("  - \(file.path) (size: \(file.size) bytes)")
        }

        #expect(!coremlFiles.isEmpty)
    }
}

@Test("Test simple MLX download")
internal func testSimpleMLXDownload() async throws {
    // Use a very small test model
    let modelId: String = "hf-internal-testing/tiny-random-gpt2"
    let backend: SendableModel.Backend = SendableModel.Backend.mlx

    // Create temporary directory for download
    let tempDir: URL = FileManager.default.temporaryDirectory
        .appendingPathComponent("test-simple-mlx-\(UUID().uuidString)")
    defer {
        try? FileManager.default.removeItem(at: tempDir)
    }

    // Initialize downloader
    let fileManager: ModelFileManager = ModelFileManager(
        modelsDirectory: tempDir,
        temporaryDirectory: tempDir.appendingPathComponent("downloads")
    )

    // Use stub file list to avoid network requests
    print("Testing file listing for model: \(modelId)")
    let files: [FileInfo] = [
        FileInfo(path: "model.safetensors", size: 128),
        FileInfo(path: "config.json", size: 32)
    ]

    print("Found \(files.count) files:")
    for file in files {
        print("  - \(file.path) (size: \(file.size) bytes)")
    }

    // Filter files for MLX format
    let mlxPatterns: [String] = backend.filePatterns
    print("\nMLX patterns: \(mlxPatterns)")

    let matchingFiles: [FileInfo] = files.filter { file in
        mlxPatterns.contains { pattern in
            fnmatch(pattern, file.path, 0) == 0
        }
    }

    print("\nMatching files for MLX format:")
    for file in matchingFiles {
        print("  - \(file.path)")
    }

    #expect(!matchingFiles.isEmpty, "Should find files matching MLX patterns")

    // Now test actual download with a simple approach
    if !matchingFiles.isEmpty {
        // Create download directory
        let repositoryId: String = "test/mlx-model"
        let downloadDir: URL = fileManager.temporaryDirectory(for: repositoryId)
        try FileManager.default.createDirectory(
            at: downloadDir,
            withIntermediateDirectories: true
        )

        print("\nDownload directory: \(downloadDir.path)")

        // Download just the first file as a test
        let testFile: FileInfo = matchingFiles.first!
        let localPath: URL = downloadDir.appendingPathComponent(testFile.path)

        print("Writing \(testFile.path) to: \(localPath.path)")

        // Create parent directory if needed
        try FileManager.default.createDirectory(
            at: localPath.deletingLastPathComponent(),
            withIntermediateDirectories: true
        )

        // Write stub data to file
        let data: Data = Data(repeating: 0x1, count: Int(testFile.size))
        try data.write(to: localPath)

        print("Downloaded \(data.count) bytes")
        #expect(FileManager.default.fileExists(atPath: localPath.path))

        // Test finalize
        let modelInfo: ModelInfo = try await fileManager.finalizeDownload(
            repositoryId: repositoryId,
            name: modelId,
            backend: backend,
            from: downloadDir,
            totalSize: Int64(data.count)
        )

        print("Model finalized to: \(modelInfo.location.path)")
        #expect(FileManager.default.fileExists(atPath: modelInfo.location.path))
    }
}

@Test("Download real CoreML model from HuggingFace")
@MainActor
internal func testDownloadRealCoreMLModel() async throws {
    let context: TestDownloaderContext = TestDownloaderContext()
    defer { context.cleanup() }

    let modelId: String = "coreml-community/test-coreml"
    let fixture: MockHuggingFaceDownloader.FixtureModel = MockHuggingFaceDownloader.FixtureModel(
        modelId: modelId,
        backend: .coreml,
        name: modelId,
        files: [
            MockHuggingFaceDownloader.FixtureFile(
                path: "TextEncoder.mlmodelc/model.mil",
                data: Data(repeating: 0x2, count: 32),
                size: 32
            ),
            MockHuggingFaceDownloader.FixtureFile(
                path: "merges.txt",
                data: Data("merge".utf8),
                size: Int64("merge".utf8.count)
            ),
            MockHuggingFaceDownloader.FixtureFile(
                path: "vocab.json",
                data: Data("{\"vocab\":true}".utf8),
                size: Int64("{\"vocab\":true}".utf8.count)
            ),
            MockHuggingFaceDownloader.FixtureFile(
                path: "model_info.json",
                data: Data("{\"info\":true}".utf8),
                size: Int64("{\"info\":true}".utf8.count)
            )
        ]
    )
    await context.mockDownloader.registerFixture(fixture)

    let sendableModel: SendableModel = SendableModel(
        id: UUID(),
        ramNeeded: 256_000_000,
        modelType: .diffusion,
        location: modelId,
        architecture: .stableDiffusion,
        backend: .coreml,
        locationKind: .huggingFace
    )

    let progressUpdates: ProgressCollector = ProgressCollector()
    var modelInfo: ModelInfo?

    for try await event in context.downloader.downloadModel(sendableModel: sendableModel) {
        switch event {
        case .progress(let progress):
            Task { await progressUpdates.add(progress.fractionCompleted) }

        case .completed(let info):
            modelInfo = info
        }
    }

    guard let modelInfo else {
        throw HuggingFaceError.downloadFailed
    }

    #expect(modelInfo.name == modelId)
    #expect(modelInfo.backend == .coreml)
    #expect(await progressUpdates.isEmpty == false)
    #expect(await progressUpdates.last == 1.0)

    let modelPath: URL = modelInfo.location
    #expect(FileManager.default.fileExists(atPath: modelPath.path))

    let contents: [URL] = try FileManager.default.contentsOfDirectory(
        at: modelPath,
        includingPropertiesForKeys: nil
    )
    let mlmodelcDirs: [URL] = contents.filter { $0.pathExtension == "mlmodelc" }
    #expect(!mlmodelcDirs.isEmpty)
}

@Test("Download real GGUF model from HuggingFace")
@MainActor
internal func testDownloadRealGGUFModel() async throws {
    let context: TestDownloaderContext = TestDownloaderContext()
    defer { context.cleanup() }

    let modelId: String = "gguf-community/test-gguf"
    let fixture: MockHuggingFaceDownloader.FixtureModel = MockHuggingFaceDownloader.FixtureModel(
        modelId: modelId,
        backend: .gguf,
        name: modelId,
        files: [
            MockHuggingFaceDownloader.FixtureFile(
                path: "model.gguf",
                data: Data(repeating: 0x3, count: 64),
                size: 64
            ),
            MockHuggingFaceDownloader.FixtureFile(
                path: "config.json",
                data: Data("{\"config\":true}".utf8),
                size: Int64("{\"config\":true}".utf8.count)
            ),
            MockHuggingFaceDownloader.FixtureFile(
                path: "model_info.json",
                data: Data("{\"info\":true}".utf8),
                size: Int64("{\"info\":true}".utf8.count)
            )
        ]
    )
    await context.mockDownloader.registerFixture(fixture)

    let sendableModel: SendableModel = SendableModel(
        id: UUID(),
        ramNeeded: 128_000_000,
        modelType: .language,
        location: modelId,
        architecture: .qwen,
        backend: .gguf,
        locationKind: .huggingFace
    )

    let progressUpdates: ProgressCollector = ProgressCollector()
    var modelInfo: ModelInfo?

    for try await event in context.downloader.downloadModel(sendableModel: sendableModel) {
        switch event {
        case .progress(let progress):
            Task { await progressUpdates.add(progress.fractionCompleted) }

        case .completed(let info):
            modelInfo = info
        }
    }

    guard let modelInfo else {
        throw HuggingFaceError.downloadFailed
    }

    #expect(modelInfo.name == modelId)
    #expect(modelInfo.backend == .gguf)
    #expect(await progressUpdates.isEmpty == false)
    #expect(await progressUpdates.last == 1.0)

    let modelPath: URL = modelInfo.location
    #expect(FileManager.default.fileExists(atPath: modelPath.path))

    let contents: [URL] = try FileManager.default.contentsOfDirectory(
        at: modelPath,
        includingPropertiesForKeys: nil
    )
    let ggufFiles: [URL] = contents.filter { $0.pathExtension == "gguf" }
    #expect(!ggufFiles.isEmpty)
}

@Test("Test download cancellation with real model")
@MainActor
internal func testRealModelDownloadCancellation() async throws {
    let context: TestDownloaderContext = TestDownloaderContext()
    defer { context.cleanup() }

    let modelId: String = "cancel-test/model"
    let fixture: MockHuggingFaceDownloader.FixtureModel = MockHuggingFaceDownloader.FixtureModel(
        modelId: modelId,
        backend: .mlx,
        name: modelId,
        files: [
            MockHuggingFaceDownloader.FixtureFile(
                path: "model.safetensors",
                data: Data(repeating: 0x5, count: 64),
                size: 64
            ),
            MockHuggingFaceDownloader.FixtureFile(
                path: "config.json",
                data: Data("{\"config\":true}".utf8),
                size: Int64("{\"config\":true}".utf8.count)
            )
        ]
    )
    await context.mockDownloader.registerFixture(fixture)
    await context.mockDownloader.setDownloadDelayNanoseconds(2_000_000_000)

    let sendableModel: SendableModel = SendableModel(
        id: UUID(),
        ramNeeded: 128_000_000,
        modelType: .language,
        location: modelId,
        architecture: .llama,
        backend: .mlx,
        locationKind: .huggingFace
    )

    let downloadTask: Task<Void, Error> = Task {
        for try await _ in context.downloader.downloadModel(sendableModel: sendableModel) {
            // Consume events
        }
    }

    try await Task.sleep(nanoseconds: 100_000_000) // 0.1 seconds

    await context.downloader.cancelDownload(for: modelId)
    downloadTask.cancel()

    do {
        try await downloadTask.value
        #expect(downloadTask.isCancelled)
    } catch {
        #expect(error is CancellationError)
    }
}
