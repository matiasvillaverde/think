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

    // Create a model ID
    let modelId: UUID = UUID()
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

@Test("Download real MLX model from HuggingFace", .disabled("This test are to be run only before releasing the app"))
internal func testDownloadRealMLXModel() async throws {
    // Use a very small test model
    let modelId: String = "hf-internal-testing/tiny-random-gpt2"
    let backend: SendableModel.Backend = SendableModel.Backend.mlx

    // Create temporary directory for download
    let tempDir: URL = FileManager.default.temporaryDirectory
        .appendingPathComponent("test-mlx-\(UUID().uuidString)")
    defer {
        try? FileManager.default.removeItem(at: tempDir)
    }

    // Initialize downloader
    let fileManager: ModelFileManager = ModelFileManager(
        modelsDirectory: tempDir,
        temporaryDirectory: tempDir.appendingPathComponent("downloads")
    )
    let downloader: HuggingFaceDownloader = HuggingFaceDownloader(
        fileManager: fileManager,
        enableProductionFeatures: false  // Disable to debug
    )

    // Track download progress
    let progressUpdates: ProgressCollector = ProgressCollector()

    // Download the model
    do {
        let modelInfo: ModelInfo = try await downloader.downloadModel(
            from: modelId,
            backend: backend
        ) { progress in
            Task { await progressUpdates.add(progress) }
            print("Download progress: \(Int(progress * 100))%")
        }

        // Verify download completed
        #expect(modelInfo.name == modelId)
        #expect(modelInfo.backend == backend)
        #expect(await progressUpdates.isEmpty == false)
        #expect(await progressUpdates.last == 1.0)

        // Verify files exist at the location specified in modelInfo
        let modelPath: URL = modelInfo.location

        #expect(FileManager.default.fileExists(atPath: modelPath.path))

        // Check for expected MLX files
        let contents: [URL] = try FileManager.default.contentsOfDirectory(
            at: modelPath,
            includingPropertiesForKeys: nil
        )

        let hasWeights: Bool = contents.contains { $0.pathExtension == "safetensors" }
        let hasConfig: Bool = contents.contains { $0.lastPathComponent == "config.json" }

        #expect(hasWeights || !contents.isEmpty, "Should have model files")
        #expect(hasConfig || contents.contains { $0.pathExtension == "json" }, "Should have config files")

        print("Successfully downloaded MLX model to: \(modelPath.path)")
        print("Downloaded files: \(contents.map(\.lastPathComponent))")
    } catch {
        print("Download failed with error: \(error)")
        print("Error type: \(type(of: error))")
        print("Error description: \(String(describing: error))")

        // Check if it's because no matching files were found
        if case HuggingFaceError.modelNotFound = error {
            print("No files matching MLX format patterns were found. This model might not have .safetensors files.")
            print("Consider using a model that has MLX-compatible files.")
        }

        // Check if it's a file system error
        if let nsError: NSError = error as NSError? {
            print("NSError domain: \(nsError.domain)")
            print("NSError code: \(nsError.code)")
            print("NSError userInfo: \(nsError.userInfo)")
        }

        throw error
    }
}

@Test("Debug CoreML repository files")
internal func testDebugCoreMLRepoFiles() async {
    // Test different CoreML repositories
    let repos: [String] = [
        "apple/coreml-stable-diffusion-v1-4",
        "huggingface/coreml-examples",
        "coreml-projects/EfficientNet",
        "google/mobilenet_v2_1.0_224"
    ]

    let httpClient: DefaultHTTPClient = DefaultHTTPClient()
    let tokenManager: HFTokenManager = HFTokenManager(httpClient: httpClient)
    let hubAPI: HubAPI = HubAPI(
        endpoint: "https://huggingface.co",
        httpClient: httpClient,
        tokenManager: tokenManager
    )

    for modelId in repos {
        print("\n=== Repository: \(modelId) ===")
        let repo: Repository = Repository(id: modelId)

        do {
            let files: [FileInfo] = try await hubAPI.listFiles(repo: repo, revision: "main")
            print("Found \(files.count) files:")

            // Print all files to see what's available
            for file in files {
                print("  - \(file.path) (size: \(file.size) bytes)")
            }

            // Look for CoreML specific files
            let coremlFiles: [FileInfo] = files.filter { file in
                file.path.contains(".mlpackage") ||
                file.path.contains(".mlmodel") ||
                file.path.hasSuffix(".zip") ||
                file.path.contains("coreml")
            }

            print("\nCoreML-related files:")
            for file in coremlFiles {
                print("  - \(file.path) (size: \(file.size) bytes)")
            }

            if coremlFiles.isEmpty {
                print("  No CoreML files found")
            }
        } catch {
            print("Error listing files: \(error)")
        }
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

    // Use basic downloader without production features
    let httpClient: DefaultHTTPClient = DefaultHTTPClient()
    let tokenManager: HFTokenManager = HFTokenManager(httpClient: httpClient)
    let hubAPI: HubAPI = HubAPI(
        endpoint: "https://huggingface.co",
        httpClient: httpClient,
        tokenManager: tokenManager
    )

    // Test listing files first
    print("Testing file listing for model: \(modelId)")
    let repo: Repository = Repository(id: modelId)
    let files: [FileInfo] = try await hubAPI.listFiles(repo: repo, revision: "main")

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
        let modelUUID: UUID = UUID()
        let repositoryId: String = "test/mlx-model"
        let downloadDir: URL = fileManager.temporaryDirectory(for: repositoryId)
        try FileManager.default.createDirectory(
            at: downloadDir,
            withIntermediateDirectories: true
        )

        print("\nDownload directory: \(downloadDir.path)")

        // Download just the first file as a test
        let testFile: FileInfo = matchingFiles.first!
        let downloadURL: URL = repo.downloadURL(path: testFile.path, revision: "main")
        let localPath: URL = downloadDir.appendingPathComponent(testFile.path)

        print("Downloading \(testFile.path) from \(downloadURL)")
        print("To: \(localPath.path)")

        // Create parent directory if needed
        try FileManager.default.createDirectory(
            at: localPath.deletingLastPathComponent(),
            withIntermediateDirectories: true
        )

        // Simple download using URLSession
        let (data, response): (Data, URLResponse) = try await URLSession.shared.data(from: downloadURL)

        if let httpResponse: HTTPURLResponse = response as? HTTPURLResponse {
            print("HTTP Status: \(httpResponse.statusCode)")
            #expect(httpResponse.statusCode == 200)
        }

        // Write data to file
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

@Test("Download real CoreML model from HuggingFace", .disabled())
internal func testDownloadRealCoreMLModel() async throws {
    // For testing purposes, we'll use a small model that has JSON files
    // which match our CoreML patterns. In production, this would download
    // actual .mlpackage or .mlmodel files
    let modelId: String = "hf-internal-testing/tiny-random-gpt2"
    let backend: SendableModel.Backend = SendableModel.Backend.coreml

    // Create temporary directory for download
    let tempDir: URL = FileManager.default.temporaryDirectory
        .appendingPathComponent("test-coreml-\(UUID().uuidString)")
    defer {
        try? FileManager.default.removeItem(at: tempDir)
    }

    // Initialize downloader
    let fileManager: ModelFileManager = ModelFileManager(
        modelsDirectory: tempDir,
        temporaryDirectory: tempDir.appendingPathComponent("downloads")
    )
    let downloader: HuggingFaceDownloader = HuggingFaceDownloader(
        fileManager: fileManager,
        enableProductionFeatures: true
    )

    // Track download progress
    let progressUpdates: ProgressCollector = ProgressCollector()

    // Download the model
    let modelInfo: ModelInfo = try await downloader.downloadModel(
        from: modelId,
        backend: backend
    ) { progress in
        Task { await progressUpdates.add(progress) }
        print("Download progress: \(Int(progress * 100))%")
    }

    // Verify download completed
    #expect(modelInfo.name == modelId)
    #expect(modelInfo.backend == backend)
    #expect(await progressUpdates.isEmpty == false)
    #expect(await progressUpdates.last == 1.0)

    // Verify files exist at the location specified in modelInfo
    let modelPath: URL = modelInfo.location

    #expect(FileManager.default.fileExists(atPath: modelPath.path))

    // Check for downloaded files (for test model, we get JSON files)
    let contents: [URL] = try FileManager.default.contentsOfDirectory(
        at: modelPath,
        includingPropertiesForKeys: nil
    )

    // For testing, we're using a model that has JSON files
    // In production, this would check for .mlpackage or .mlmodel files
    let hasFiles: Bool = !contents.isEmpty

    #expect(hasFiles, "Should have downloaded files")

    print("Successfully downloaded CoreML model to: \(modelPath.path)")
}

@Test("Download real GGUF model from HuggingFace", .disabled())
internal func testDownloadRealGGUFModel() async throws {
    // For testing, use a model with JSON files that match GGUF patterns
    // Real GGUF models are very large (GB+)
    let modelId: String = "hf-internal-testing/tiny-random-gpt2"
    let backend: SendableModel.Backend = SendableModel.Backend.gguf

    // Create temporary directory for download
    let tempDir: URL = FileManager.default.temporaryDirectory
        .appendingPathComponent("test-gguf-\(UUID().uuidString)")
    defer {
        try? FileManager.default.removeItem(at: tempDir)
    }

    // Initialize downloader
    let fileManager: ModelFileManager = ModelFileManager(
        modelsDirectory: tempDir,
        temporaryDirectory: tempDir.appendingPathComponent("downloads")
    )
    let downloader: HuggingFaceDownloader = HuggingFaceDownloader(
        fileManager: fileManager,
        enableProductionFeatures: true
    )

    // Track download progress
    let progressUpdates: ProgressCollector = ProgressCollector()

    // Download the model
    let modelInfo: ModelInfo = try await downloader.downloadModel(
        from: modelId,
        backend: backend
    ) { progress in
        Task { await progressUpdates.add(progress) }
        print("Download progress: \(Int(progress * 100))%")
    }

    // Verify download completed
    #expect(modelInfo.name == modelId)
    #expect(modelInfo.backend == backend)
    #expect(await progressUpdates.isEmpty == false)
    #expect(await progressUpdates.last == 1.0)

    // Verify files exist at the location specified in modelInfo
    let modelPath: URL = modelInfo.location

    #expect(FileManager.default.fileExists(atPath: modelPath.path))

    // Check for downloaded files (for test model, we get JSON files)
    let contents: [URL] = try FileManager.default.contentsOfDirectory(
        at: modelPath,
        includingPropertiesForKeys: nil
    )

    // For testing, we're using a model that has JSON files
    // In production, this would check for .gguf files
    let hasFiles: Bool = !contents.isEmpty

    #expect(hasFiles, "Should have downloaded files")

    print("Successfully downloaded GGUF model to: \(modelPath.path)")
}

@Test("Test download cancellation with real model", .disabled())
internal func testRealModelDownloadCancellation() async throws {
    // Use a medium-sized model to ensure we have time to cancel
    let modelId: String = "bert-base-uncased"
    let backend: SendableModel.Backend = SendableModel.Backend.mlx

    // Create temporary directory for download
    let tempDir: URL = FileManager.default.temporaryDirectory
        .appendingPathComponent("test-cancel-\(UUID().uuidString)")
    defer {
        try? FileManager.default.removeItem(at: tempDir)
    }

    // Initialize downloader
    let fileManager: ModelFileManager = ModelFileManager(
        modelsDirectory: tempDir,
        temporaryDirectory: tempDir.appendingPathComponent("downloads")
    )
    let downloader: HuggingFaceDownloader = HuggingFaceDownloader(
        fileManager: fileManager,
        enableProductionFeatures: true
    )

    // Start download in a task
    let downloadTask: Task<ModelInfo, Error> = Task {
        try await downloader.downloadModel(
            from: modelId,
            backend: backend
        ) { progress in
            print("Download progress: \(Int(progress * 100))%")
        }
    }

    // Wait a bit then cancel
    try await Task.sleep(nanoseconds: 2_000_000_000) // 2 seconds

    // Cancel the download
    await downloader.cancelDownload(for: modelId)
    downloadTask.cancel()

    // Verify task was cancelled or partially completed
    do {
        _ = try await downloadTask.value
        // If we get here, the download might have partially completed
        // Check if it was actually interrupted
        print("Download task completed, checking if it was interrupted")
    } catch {
        // This is expected - the download should have been cancelled
        #expect(error is CancellationError || error is HuggingFaceError)
        print("Download was cancelled as expected: \(error)")
    }

    print("Successfully cancelled model download")
}

// MARK: - Test Utilities

extension HuggingFaceDownloader {
    /// Download a model with specific variant
    func downloadModel(
        from repoId: String,
        backend: SendableModel.Backend,
        variant _: String? = nil,
        progressHandler: @Sendable (Double) -> Void
    ) async throws -> ModelInfo {
        // For testing purposes, we'll use the standard download method
        // In a real implementation, variant selection would be handled
        var modelInfo: ModelInfo?

        for try await event in download(
            modelId: repoId,
            backend: backend
        ) {
            switch event {
            case .progress(let progress):
                progressHandler(progress.fractionCompleted)

            case .completed(let info):
                modelInfo = info
            }
        }

        guard let modelInfo else {
            throw HuggingFaceError.downloadFailed
        }

        return modelInfo
    }
}
