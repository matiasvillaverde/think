import Foundation
@testable import ModelDownloader
import Testing

// MARK: - Repository Tests

@Test("Repository should parse repo ID correctly")
internal func testRepositoryParsing() {
    // Test model repository
    let modelRepo: Repository = Repository(id: "facebook/opt-125m")
    #expect(modelRepo.namespace == "facebook")
    #expect(modelRepo.name == "opt-125m")
    #expect(modelRepo.type == .model)
    #expect(modelRepo.endpoint == "https://huggingface.co")

    // Test dataset repository
    let datasetRepo: Repository = Repository(id: "datasets/squad", type: .dataset)
    #expect(datasetRepo.namespace.isEmpty)
    #expect(datasetRepo.name == "squad")
    #expect(datasetRepo.type == .dataset)

    // Test space repository
    let spaceRepo: Repository = Repository(id: "spaces/stable-diffusion/webui", type: .space)
    #expect(spaceRepo.namespace == "stable-diffusion")
    #expect(spaceRepo.name == "webui")
    #expect(spaceRepo.type == .space)

    // Test repository without namespace
    let simpleRepo: Repository = Repository(id: "gpt2")
    #expect(simpleRepo.namespace.isEmpty)
    #expect(simpleRepo.name == "gpt2")
}

@Test("Repository should construct correct API URLs")
internal func testRepositoryAPIURLs() {
    let repo: Repository = Repository(id: "facebook/opt-125m")

    // Test files API URL
    let filesURL: URL = repo.filesAPIURL(revision: "main")
    #expect(filesURL.absoluteString == "https://huggingface.co/api/models/facebook/opt-125m/tree/main?recursive=true")

    // Test with custom revision
    let revisionURL: URL = repo.filesAPIURL(revision: "v1.0")
    #expect(
        revisionURL.absoluteString == "https://huggingface.co/api/models/facebook/opt-125m/tree/v1.0?recursive=true"
    )

    // Test download URL
    let downloadURL: URL = repo.downloadURL(path: "config.json", revision: "main")
    #expect(downloadURL.absoluteString == "https://huggingface.co/facebook/opt-125m/resolve/main/config.json")

    // Test dataset repository
    let datasetRepo: Repository = Repository(id: "datasets/squad", type: .dataset)
    let datasetFilesURL: URL = datasetRepo.filesAPIURL(revision: "main")
    #expect(datasetFilesURL.absoluteString == "https://huggingface.co/api/datasets/squad/tree/main?recursive=true")
}

@Test("Repository should support custom endpoints")
internal func testCustomEndpoint() {
    let repo: Repository = Repository(id: "mymodel", endpoint: "https://my-hub.com")
    #expect(repo.endpoint == "https://my-hub.com")

    let filesURL: URL = repo.filesAPIURL(revision: "main")
    #expect(filesURL.absoluteString == "https://my-hub.com/api/models/mymodel/tree/main?recursive=true")
}

// MARK: - File Info Tests

@Test("FileInfo should be created correctly")
internal func testFileInfoCreation() {
    let fileInfo: FileInfo = FileInfo(
        path: "pytorch_model.bin",
        size: 1_024_000,
        lfs: LFSInfo(
            oid: "abc123",
            size: 1_024_000,
            pointerSize: 134
        )
    )

    #expect(fileInfo.path == "pytorch_model.bin")
    #expect(fileInfo.size == 1_024_000)
    #expect(fileInfo.lfs?.oid == "abc123")
    #expect(fileInfo.lfs?.size == 1_024_000)
    #expect(fileInfo.isLFS)
}

@Test("FileInfo should parse from JSON correctly")
internal func testFileInfoJSONParsing() {
    let json: [String: Any] = [
        "path": "config.json",
        "size": 512,
        "type": "file",
        "lfs": [
            "oid": "sha256:abcdef",
            "size": 512,
            "pointer_size": 120
        ]
    ]

    let fileInfo: FileInfo? = FileInfo.from(json: json)
    #expect(fileInfo != nil)
    #expect(fileInfo?.path == "config.json")
    #expect(fileInfo?.size == 512)
    #expect(fileInfo?.lfs?.oid == "sha256:abcdef")
}

// MARK: - Hub API Tests

@Test("HubAPI should initialize with default values")
internal func testHubAPIInitialization() {
    let mockFileManager: MockHFFileManager = MockHFFileManager()
    let mockHTTPClient: ConfigurableMockHTTPClient = ConfigurableMockHTTPClient()

    let api: HubAPI = HubAPI(
        fileManager: mockFileManager,
        httpClient: mockHTTPClient
    )

    // API initializes without throwing - that's enough for this test
    // API is successfully initialized
}

@Test("HubAPI should list files in repository")
internal func testListFiles() async throws {
    let mockFileManager: MockHFFileManager = MockHFFileManager()
    let mockHTTPClient: ConfigurableMockHTTPClient = ConfigurableMockHTTPClient()

    // Mock the API response
    let responseJSON: [[String: Any]] = [
        [
            "path": "config.json",
            "size": 665,
            "type": "file"
        ],
        [
            "path": "pytorch_model.bin",
            "size": 548_118_077,
            "type": "file",
            "lfs": [
                "oid": "sha256:abcdef",
                "size": 548_118_077,
                "pointer_size": 134
            ]
        ]
    ]

    let responseData: Data = try JSONSerialization.data(withJSONObject: responseJSON)
    mockHTTPClient.mockResponses[
        "https://huggingface.co/api/models/facebook/opt-125m/tree/main?recursive=true"
    ] = HTTPClientResponse(
        data: responseData,
        statusCode: 200
    )

    let api: HubAPI = HubAPI(
        fileManager: mockFileManager,
        httpClient: mockHTTPClient
    )

    let files: [FileInfo] = try await api.listFiles(
        repo: Repository(id: "facebook/opt-125m"),
        revision: "main",
        includePattern: nil,
        excludePattern: nil
    )

    #expect(files.count == 2)
    #expect(files[0].path == "config.json")
    #expect(files[0].size == 665)
    #expect(files[1].path == "pytorch_model.bin")
    #expect(files[1].isLFS)
}

@Test("HubAPI should filter files by pattern")
internal func testFilePatternFiltering() async throws {
    let mockFileManager: MockHFFileManager = MockHFFileManager()
    let mockHTTPClient: ConfigurableMockHTTPClient = ConfigurableMockHTTPClient()

    // Mock response with various file types
    let responseJSON: [[String: Any]] = [
        ["path": "config.json", "size": 665, "type": "file"],
        ["path": "pytorch_model.bin", "size": 1_000, "type": "file"],
        ["path": "model.safetensors", "size": 2_000, "type": "file"],
        ["path": "tokenizer.json", "size": 500, "type": "file"],
        ["path": "README.md", "size": 100, "type": "file"]
    ]

    let responseData: Data = try JSONSerialization.data(withJSONObject: responseJSON)
    mockHTTPClient.mockResponses[
        "https://huggingface.co/api/models/test/model/tree/main?recursive=true"
    ] = HTTPClientResponse(
        data: responseData,
        statusCode: 200
    )

    let api: HubAPI = HubAPI(
        fileManager: mockFileManager,
        httpClient: mockHTTPClient
    )

    // Test include pattern
    let jsonFiles: [FileInfo] = try await api.listFiles(
        repo: Repository(id: "test/model"),
        revision: "main",
        includePattern: "*.json",
        excludePattern: nil
    )

    #expect(jsonFiles.count == 2)
    #expect(jsonFiles.allSatisfy { $0.path.hasSuffix(".json") })

    // Test exclude pattern
    let nonReadmeFiles: [FileInfo] = try await api.listFiles(
        repo: Repository(id: "test/model"),
        revision: "main",
        includePattern: nil,
        excludePattern: "README*"
    )

    #expect(nonReadmeFiles.count == 4)
    #expect(!nonReadmeFiles.contains { $0.path == "README.md" })
}

@Test("HubAPI should handle authentication")
internal func testAuthenticatedRequest() async throws {
    let mockEnvironment: [String: String] = ["HF_TOKEN": "test_token"]
    let mockFileManager: MockHFFileManager = MockHFFileManager()
    let mockHTTPClient: ConfigurableMockHTTPClient = ConfigurableMockHTTPClient()

    // Create token manager with mock token
    let tokenManager: HFTokenManager = HFTokenManager(
        environment: mockEnvironment,
        fileManager: mockFileManager,
        httpClient: mockHTTPClient
    )

    // Mock empty response for simplicity
    mockHTTPClient.mockResponses[
        "https://huggingface.co/api/models/private/model/tree/main?recursive=true"
    ] = HTTPClientResponse(
        data: Data("[]".utf8),
        statusCode: 200
    )

    let api: HubAPI = HubAPI(
        fileManager: mockFileManager,
        httpClient: mockHTTPClient,
        tokenManager: tokenManager
    )

    // This should succeed with authentication
    let files: [FileInfo] = try await api.listFiles(
        repo: Repository(id: "private/model"),
        revision: "main",
        includePattern: nil,
        excludePattern: nil
    )

    #expect(files.isEmpty) // Empty response is fine, we're testing auth
}

// MARK: - Mock Types

private final class MockHFFileManager: HFFileManagerProtocol, @unchecked Sendable {
    var mockFileContents: [String: String] = [:]
    var mockExpandedPaths: [String: String] = [:]
    var mockFileExists: [String: Bool] = [:]

    deinit {
        // Cleanup mock resources if needed
    }

    func fileExists(atPath path: String) -> Bool {
        let expandedPath: String = expandTildeInPath(path)
        return mockFileExists[expandedPath] ?? (mockFileContents[expandedPath] != nil)
    }

    func contents(atPath path: String) -> String? {
        let expandedPath: String = expandTildeInPath(path)
        return mockFileContents[expandedPath]
    }

    func expandTildeInPath(_ path: String) -> String {
        mockExpandedPaths[path] ?? path.replacingOccurrences(of: "~", with: "/Users/test")
    }
}

// Using ConfigurableMockHTTPClient from TestMocks.swift
