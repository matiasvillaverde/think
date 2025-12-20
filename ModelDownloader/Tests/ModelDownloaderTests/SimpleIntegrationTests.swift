import Abstractions
import Foundation
@testable import ModelDownloader
import Testing

// MARK: - Simple Integration Tests

@Test("HuggingFaceDownloader initializes with production features")
internal func testProductionDownloaderInitialization() {
    let mockFileManager: MockFileManager = MockFileManager()

    let _: HuggingFaceDownloader = HuggingFaceDownloader.createProductionDownloader(
        fileManager: mockFileManager
    )

    // Verify it exists
    // Downloader is successfully initialized
}

@Test("Rate limiter integration works correctly")
internal func testRateLimiterIntegration() async throws {
    let rateLimiter: HuggingFaceRateLimiter = HuggingFaceRateLimiter()

    // Test authenticated rate limiting
    try await rateLimiter.waitIfNeeded(isAuthenticated: true)

    // Test unauthenticated rate limiting
    try await rateLimiter.waitIfNeeded(isAuthenticated: false)

    // Log status
    await rateLimiter.logStatus(isAuthenticated: true)
    await rateLimiter.logStatus(isAuthenticated: false)

    // Should complete without errors
    #expect(true)
}

@Test("Download coordinator with retry logic")
internal func testDownloadCoordinatorWithRetry() async throws {
    let mockDownloader: MockStreamingDownloaderSimple = MockStreamingDownloaderSimple()
    let retryPolicy: ExponentialBackoffRetryPolicy = ExponentialBackoffRetryPolicy(
        maxRetries: 2,
        baseDelay: 0.01
    )

    let retryableDownloader: RetryableDownloader = RetryableDownloader(
        downloader: mockDownloader,
        retryPolicy: retryPolicy
    )

    let coordinator: DownloadCoordinator = DownloadCoordinator(
        downloader: retryableDownloader,
        maxConcurrentDownloads: 2
    )

    let files: [FileDownloadInfo] = [
        FileDownloadInfo(
            url: URL(string: "https://example.com/file1.bin")!,
            localPath: FileManager.default.temporaryDirectory.appendingPathComponent("file1.bin"),
            size: 1_000,
            path: "file1.bin"
        )
    ]

    let progressActor: ProgressActor = ProgressActor()
    let results: [DownloadResult] = try await coordinator.downloadFiles(
        files,
        headers: [:]
    ) { progress in
        Task {
            await progressActor.recordProgress()
        }
        #expect(progress.totalFiles == 1)
    }

    #expect(results.count == 1)
    #expect(results[0].success)
    let progressReceived: Bool = await progressActor.hasProgress()
    #expect(progressReceived)
}

@Test("Model validation integration")
internal func testModelValidationIntegration() async throws {
    let validator: ModelValidator = ModelValidator()
    let extractor: ModelMetadataExtractor = ModelMetadataExtractor()

    // Test with minimal valid configuration
    let config: LanguageModelConfiguration = LanguageModelConfiguration(
        modelType: "gpt2",
        architectures: ["GPT2LMHeadModel"],
        vocabSize: 50_257,
        hiddenSize: 768,
        intermediateSize: nil,
        numHiddenLayers: 12,
        numAttentionHeads: 12,
        numKeyValueHeads: nil,
        rmsNormEps: nil,
        maxPositionEmbeddings: 1_024,
        ropeScaling: nil,
        ropeTheta: nil,
        bosTokenId: nil,
        eosTokenId: 50_256,
        padTokenId: nil,
        tieWordEmbeddings: nil,
        torchDtype: "float32"
    )

    // Validate for different formats
    let mlxValidation: ModelValidationResult = try await validator.validateModel(
        configuration: config,
        backend: SendableModel.Backend.mlx
    )
    #expect(mlxValidation.isCompatible)

    // Extract metadata
    let files: [FileInfo] = [
        FileInfo(path: "pytorch_model.bin", size: 500_000_000, lfs: nil),
        FileInfo(path: "config.json", size: 1_024, lfs: nil)
    ]

    // Extract metadata - use explicit variable to satisfy SwiftLint
    let extractedData: Any = try await extractor.extractMetadata(
        configuration: config,
        files: files,
        modelId: "gpt2"
    )

    // Use Mirror to access properties dynamically to avoid type ambiguity
    let mirror: Mirror = Mirror(reflecting: extractedData)
    let modelType: String? = mirror.children.first { $0.label == "modelType" }?.value as? String
    let architecture: String? = mirror.children.first { $0.label == "architecture" }?.value as? String
    let parameters: String? = mirror.children.first { $0.label == "parameters" }?.value as? String

    #expect(modelType == "gpt2")
    #expect(architecture == "GPT2LMHeadModel")
    #expect((parameters?.count ?? 0) != 0)
}

@Test("Disk space validation integration")
internal func testDiskSpaceValidationIntegration() async throws {
    let validator: DiskSpaceValidator = DiskSpaceValidator()

    // Test with temporary directory
    let tempDir: URL = FileManager.default.temporaryDirectory

    // Should have space for small files
    let hasSpace: Bool = try await validator.hasEnoughSpace(
        for: 1_000_000, // 1MB
        at: tempDir
    )

    #expect(hasSpace)
}

@Test("Logger integration")
internal func testLoggerIntegration() async {
    let logger: ModelDownloaderLogger = ModelDownloaderLogger(
        subsystem: "test",
        category: "integration"
    )

    // Test different log levels
    await logger.debug("Debug message")
    await logger.info("Info message")
    await logger.warning("Warning message")
    await logger.error("Error message")

    // Test with metadata
    await logger.logDownloadStart(
        modelId: "test/model",
        backend: SendableModel.Backend.mlx,
        totalSize: 1_000_000
    )

    let progress: DownloadProgress = DownloadProgress(
        bytesDownloaded: 500_000,
        totalBytes: 1_000_000,
        filesCompleted: 1,
        totalFiles: 2,
        currentFileName: "model.bin"
    )

    await logger.logDownloadProgress(
        modelId: "test/model",
        progress: progress
    )

    await logger.logDownloadComplete(
        modelId: "test/model",
        duration: 10.5,
        totalSize: 1_000_000
    )

    // Should complete without errors
    #expect(true)
}

// MARK: - Mock Types

private actor MockStreamingDownloaderSimple: StreamingDownloaderProtocol {
    func download(
        from _: URL,
        to destination: URL,
        headers _: [String: String],
        progressHandler: @Sendable (Double) -> Void
    ) async throws -> URL {
        // Simulate progress
        for step in 0...10 {
            progressHandler(Double(step) / 10.0)
            try await Task.sleep(nanoseconds: 1_000_000) // 1ms
        }

        // Create empty file
        try Data().write(to: destination)
        return destination
    }

    func downloadResume(
        from url: URL,
        to destination: URL,
        headers: [String: String],
        progressHandler: @Sendable (Double) -> Void
    ) async throws -> URL {
        try await download(from: url, to: destination, headers: headers, progressHandler: progressHandler)
    }

    func cancel(url _: URL) {}
    func cancelAll() {}
    func pause(url _: URL) {}
    func pauseAll() {}
    func resume(url _: URL) {}
    func resumeAll() {}
}

private actor ProgressActor {
    private var progressRecorded: Bool = false

    func recordProgress() {
        progressRecorded = true
    }

    func hasProgress() -> Bool {
        progressRecorded
    }
}
