import Foundation
@testable import ModelDownloader
import Testing

// MARK: - Integration Tests

/*
@Test("Complete download flow with all production features")
internal func testCompleteDownloadFlow() async throws {
    // Skip for now - need proper mock setup
    #expect(true, "Integration test placeholder")
    
    // Create production-ready downloader with all features
    let tokenManager: HFTokenManager = HFTokenManager(
        httpClient: mockHTTPClient,
        fileManager: mockFileManager
    )
    
    let hubAPI: HubAPI = HubAPI.withRateLimiting(
        httpClient: mockHTTPClient,
        tokenManager: tokenManager
    )
    
    let streamingDownloader: StreamingDownloader = StreamingDownloader.withTimeout(
        urlSession: mockSession
    )
    
    let retryPolicy = ExponentialBackoffRetryPolicy(
        maxRetries: 3,
        baseDelay: 0.1 // Short for tests
    )
    
    let retryableDownloader = RetryableDownloader(
        downloader: streamingDownloader,
        retryPolicy: retryPolicy
    )
    
    let downloadCoordinator: DownloadCoordinator = DownloadCoordinator(
        downloader: retryableDownloader,
        maxConcurrentDownloads: 2
    )
    
    let configLoader = LanguageModelConfigurationFromHub(
        hubAPI: hubAPI,
        tokenManager: tokenManager
    )
    
    let validator = ModelValidator()
    let extractor = ModelMetadataExtractor()
    
    let downloader = HuggingFaceDownloaderV2(
        hubAPI: hubAPI,
        tokenManager: tokenManager,
        downloadCoordinator: downloadCoordinator,
        configLoader: configLoader,
        validator: validator,
        metadataExtractor: extractor
    )
    
    // Test download
    let progressCollector = ProgressCollector()
    
    let modelInfo: ModelInfo = try await downloader.download(
        modelId: "test/model",
        backend: .mlx
    ) { progress in
        Task {
            await progressCollector.addDownloadProgress(progress)
        }
    }
    
    #expect(modelInfo.modelId == "test/model")
    #expect(modelInfo.format == SendableModel.Backend.mlx)
    #expect(modelInfo.totalSize > 0)
    
    let progressUpdates = await progressCollector.getDownloadProgress()
    #expect(!progressUpdates.isEmpty)
    #expect(progressUpdates.last?.isComplete == true)
}

@Test("Download with authentication and rate limiting")
internal func testAuthenticatedDownloadWithRateLimiting() async throws {
    let mockHTTPClient: MockHTTPClient = MockHTTPClient()
    let mockFileManager = MockHFFileManager()
    
    // Set up authentication token
    mockFileManager.mockFileContents["~/.cache/huggingface/token"] = "test_token_123"
    
    let tokenManager: HFTokenManager = HFTokenManager(
        fileManager: mockFileManager,
        httpClient: mockHTTPClient
    )
    
    // Verify token is found
    let token = await tokenManager.getToken()
    #expect(token == "test_token_123")
    
    // Create rate-limited HubAPI
    let hubAPI: HubAPI = HubAPI.withRateLimiting(
        httpClient: mockHTTPClient,
        tokenManager: tokenManager
    )
    
    // Mock private model response
    mockHTTPClient.mockResponses["https://huggingface.co/api/models/private/model/tree/main"] = HTTPClientResponse(
        data: Data("[]".utf8),
        statusCode: 200,
        headers: [:]
    )
    
    // Should succeed with authentication
    let files: [FileInfo] = try await hubAPI.listFiles(
        repo: Repository(id: "private/model"),
        revision: "main"
    )
    
    #expect(files.isEmpty) // Empty response but authenticated
    
    // Verify auth header was sent
    let capturedHeaders = mockHTTPClient.capturedHeaders["https://huggingface.co/api/models/private/model/tree/main"]
    #expect(capturedHeaders?["Authorization"] == "Bearer test_token_123")
}

@Test("Download with retry on transient failures")
internal func testDownloadWithRetryLogic() async throws {
    let mockSession = MockURLSessionWithTransientFailures()
    let downloader = StreamingDownloader(urlSession: mockSession)
    
    let retryPolicy = ExponentialBackoffRetryPolicy(
        maxRetries: 3,
        baseDelay: 0.01,
        jitter: 0
    )
    
    let retryableDownloader = RetryableDownloader(
        downloader: downloader,
        retryPolicy: retryPolicy
    )
    
    // Configure to fail twice then succeed
    await mockSession.setFailureCount(2)
    
    let url: URL = URL(string: "https://example.com/model.bin")!
    let destination: FileManager = FileManager.default.temporaryDirectory.appendingPathComponent("test-model.bin")
    
    let result: URL = try await retryableDownloader.download(
        from: url,
        to: destination,
        headers: [:]
    ) { _ in }
    
    #expect(result == destination)
    
    let attempts = await mockSession.getAttemptCount()
    #expect(attempts == 3) // 2 failures + 1 success
    
    // Clean up
    try? FileManager.default.removeItem(at: destination)
}

@Test("Download with disk space validation")
internal func testDownloadWithDiskSpaceValidation() async throws {
    let mockFileManager = MockFileManagerWithSpace()
    let validator = DiskSpaceValidator(
        fileManager: mockFileManager,
        minimumFreeSpaceMultiplier: 1.5
    )
    
    let coordinator: DownloadCoordinator = DownloadCoordinator()
    
    // Set up mock with limited space
    await mockFileManager.setFreeSpace(1_000_000_000) // 1GB free
    
    let files: [String] = [
        FileDownloadInfo(
            url: URL(string: "https://example.com/large.bin")!,
            localPath: URL(fileURLWithPath: "/tmp/large.bin"),
            size: 800_000_000, // 800MB file needs 1.2GB with multiplier
            path: "large.bin"
        )
    ]
    
    // Should fail validation
    do {
        _ = try await coordinator.downloadFilesWithValidation(
            files,
            to: URL(fileURLWithPath: "/tmp"),
            headers: [:],
            validateSpace: true
        ) { _ in }
        #expect(Bool(false), "Should have failed disk space validation")
    } catch {
        #expect(error is HuggingFaceError)
    }
}

@Test("Model validation and metadata extraction")
internal func testModelValidationAndMetadata() async throws {
    let validator = ModelValidator()
    let extractor = ModelMetadataExtractor()
    
    // Create a valid Llama configuration
    let config = LanguageModelConfiguration(
        modelType: "llama",
        architectures: ["LlamaForCausalLM"],
        vocabSize: 32_000,
        hiddenSize: 4_096,
        intermediateSize: 11_008,
        numHiddenLayers: 32,
        numAttentionHeads: 32,
        numKeyValueHeads: 32,
        rmsNormEps: 1e-06,
        maxPositionEmbeddings: 4_096,
        ropeScaling: nil,
        ropeTheta: 10_000.0,
        bosTokenId: 1,
        eosTokenId: 2,
        padTokenId: 0,
        tieWordEmbeddings: false,
        torchDtype: "float16"
    )
    
    // Validate model
    let validation: Bool = try await validator.validateModel(
        configuration: config,
        backend: .mlx
    )
    
    #expect(validation.isCompatible)
    #expect(validation.errors.isEmpty)
    
    // Extract metadata
    let files: [String] = [
        FileInfo(path: "model-00001-of-00002.safetensors", size: 7_000_000_000, lfs: nil),
        FileInfo(path: "model-00002-of-00002.safetensors", size: 6_500_000_000, lfs: nil),
        FileInfo(path: "config.json", size: 1_024, lfs: nil),
        FileInfo(path: "tokenizer.json", size: 2_048, lfs: nil)
    ]
    
    let metadata = try await extractor.extractMetadata(
        configuration: config,
        files: files,
        modelId: "meta-llama/Llama-2-7b-hf"
    )
    
    #expect(metadata.modelType == "llama")
    #expect(metadata.architecture == "LlamaForCausalLM")
    #expect(metadata.parameters == "7B")
    #expect(metadata.contextLength == 4_096)
}

@Test("End-to-end download cancellation")
internal func testEndToEndCancellation() async throws {
    let mockSession = MockURLSessionWithDelay()
    await mockSession.setDelay(1.0) // 1 second delay per file
    
    let downloader = StreamingDownloader(urlSession: mockSession)
    let coordinator: DownloadCoordinator = DownloadCoordinator(downloader: downloader)
    
    let files: [String] = (1...5).map { i in
        FileDownloadInfo(
            url: URL(string: "https://example.com/file\(i).bin")!,
            localPath: URL(fileURLWithPath: "/tmp/file\(i).bin"),
            size: 1_000_000,
            path: "file\(i).bin"
        )
    }
    
    let downloadTask: Task<ModelInfo, Error> = Task {
        try await coordinator.downloadFiles(
            files,
            headers: [:]
        ) { _ in }
    }
    
    // Cancel after short delay
    try await Task.sleep(nanoseconds: 100_000_000) // 0.1 seconds
    downloadTask.cancel()
    
    do {
        _ = try await downloadTask.value
        #expect(Bool(false), "Should have been cancelled")
    } catch {
        #expect(error is CancellationError)
    }
}

// MARK: - Helper Functions

private func configureMocksForIntegration(
    httpClient: MockHTTPClient,
    fileManager: MockHFFileManager,
    session: MockURLSession
) {
    // Mock model files response
    let filesJSON: [[String: Any]] = [
        [
            "path": "model_weights.safetensors",
            "size": 500_000_000,
            "type": "file",
            "lfs": [
                "oid": "sha256:abc123",
                "size": 500_000_000,
                "pointer_size": 134
            ]
        ],
        [
            "path": "config.json",
            "size": 1_024,
            "type": "file"
        ],
        [
            "path": "tokenizer.json",
            "size": 2_048,
            "type": "file"
        ]
    ]
    
    let filesData = try! JSONSerialization.data(withJSONObject: filesJSON)
    httpClient.mockResponses["https://huggingface.co/api/models/test/model/tree/main"] = HTTPClientResponse(
        data: filesData,
        statusCode: 200
    )
    
    // Mock config.json
    let configJSON: String = """
    {
        "model_type": "gpt2",
        "architectures": ["GPT2LMHeadModel"],
        "vocab_size": 50257,
        "hidden_size": 768,
        "num_hidden_layers": 12,
        "num_attention_heads": 12,
        "max_position_embeddings": 1024,
        "torch_dtype": "float32"
    }
    """
    
    httpClient.mockResponses["https://huggingface.co/test/model/resolve/main/config.json"] = HTTPClientResponse(
        data: Data(configJSON.utf8),
        statusCode: 200
    )
    
    // Mock file metadata
    httpClient.mockResponses["https://huggingface.co/api/models/test/model/paths-info/main"] = HTTPClientResponse(
        data: Data("{}".utf8),
        statusCode: 200,
        headers: ["ETag": "\"test-etag\""]
    )
    
    // Mock file downloads
    session.mockData = Data(repeating: 0, count: 1_000)
    session.mockResponse = HTTPURLResponse(
        url: URL(string: "https://huggingface.co/test/model/resolve/main/model_weights.safetensors")!,
        statusCode: 200,
        httpVersion: nil,
        headerFields: ["Content-Length": "500000000"]
    )
}

// MARK: - Mock Types

private actor MockURLSessionWithTransientFailures: StreamingDownloaderProtocol {
    private var failureCount: Int = 0
    private var attemptCount: Int = 0
    
    func setFailureCount(_ count: Int) {
        failureCount = count
    }
    
    func getAttemptCount() -> Int {
        attemptCount
    }
    
    func download(
        from url: URL,
        to destination: URL,
        headers: [String: String],
        progressHandler: @Sendable (Double) -> Void
    ) async throws -> URL {
        attemptCount += 1
        
        if attemptCount <= failureCount {
            throw URLError(.networkConnectionLost)
        }
        
        progressHandler(1.0)
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
    
    func cancel(url: URL) {}
    func cancelAll() {}
}

private actor MockURLSessionWithDelay {
    private var delay: TimeInterval = 0
    
    func setDelay(_ seconds: TimeInterval) {
        delay = seconds
    }
}

private actor MockFileManagerWithSpace: FileSystemProtocol {
    private var freeSpace: Int64 = 0
    
    func setFreeSpace(_ bytes: Int64) {
        freeSpace = bytes
    }
    
    func getFreeSpace(forPath path: String) async throws -> Int64? {
        freeSpace
    }
}

// Reuse existing mock types
private actor ProgressCollector {
    private var progressValues: [Any] = []
    private var downloadProgressValues: [Any] = []
    
    func addProgress(_ value: Double) {
        progressValues.append(value)
    }
    
    func addDownloadProgress(_ progress: DownloadProgress) {
        downloadProgressValues.append(progress)
    }
    
    func getProgress() -> [Double] {
        progressValues
    }
    
    func getDownloadProgress() -> [DownloadProgress] {
        downloadProgressValues
    }
}
*/
