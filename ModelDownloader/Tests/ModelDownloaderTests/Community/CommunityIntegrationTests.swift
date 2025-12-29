import Abstractions
import Foundation
@testable import ModelDownloader
import Testing

extension APITests {
    @Test("End-to-end: Explore, discover, and prepare for download")
    @MainActor
    func testCompleteModelDiscoveryFlow() async throws {
        // Setup comprehensive mock responses
        let mockClient: CommunityMockHTTPClient = CommunityMockHTTPClient()

        // Mock search response
        mockClient.responses["/api/models"] = HTTPClientResponse(
            data: Data("""
            [
                {
                    "modelId": "mlx-community/Llama-3.2-1B-Instruct-4bit",
                    "author": "mlx-community",
                    "downloads": 25000,
                    "likes": 450,
                    "tags": ["text-generation", "llama", "instruct", "4bit"],
                    "lastModified": "2024-01-25T10:00:00Z"
                }
            ]
            """.utf8),
            statusCode: 200,
            headers: [:]
        )

        // Mock detailed model info for discoverModel
        mockClient.responses["/api/models/mlx-community/Llama-3.2-1B-Instruct-4bit"] = HTTPClientResponse(
            data: Data("""
            {
                "modelId": "mlx-community/Llama-3.2-1B-Instruct-4bit",
                "author": "mlx-community",
                "downloads": 25000,
                "likes": 450,
                "tags": ["text-generation", "llama", "instruct", "4bit", "mlx"],
                "lastModified": "2024-01-25T10:00:00Z",
                "siblings": [
                    {"rfilename": "model.safetensors", "size": 1073741824},
                    {"rfilename": "config.json", "size": 2048},
                    {"rfilename": "tokenizer.json", "size": 512000},
                    {"rfilename": "tokenizer_config.json", "size": 1024},
                    {"rfilename": "README.md", "size": 4096}
                ]
            }
            """.utf8),
            statusCode: 200,
            headers: [:]
        )

        // Mock model files for discovery (tree API used during search)
        mockClient.responses["/api/models/mlx-community/Llama-3.2-1B-Instruct-4bit/tree/main"] = HTTPClientResponse(
            data: Data("""
            [
                {"path": "model.safetensors", "size": 1073741824, "type": "file"},
                {"path": "config.json", "size": 2048, "type": "file"},
                {"path": "tokenizer.json", "size": 512000, "type": "file"},
                {"path": "tokenizer_config.json", "size": 1024, "type": "file"},
                {"path": "README.md", "size": 4096, "type": "file"}
            ]
            """.utf8),
            statusCode: 200,
            headers: [:]
        )

        // Mock model card
        mockClient.responses["/mlx-community/Llama-3.2-1B-Instruct-4bit/raw/main/README.md"] = HTTPClientResponse(
            data: Data("""
            # Llama 3.2 1B Instruct 4bit

            This model is a 4-bit quantized version of Llama 3.2 1B Instruct.

            ## Requirements
            - RAM: 4GB minimum
            - Processor: Apple Silicon (M1 or newer)

            ## Usage
            ```python
            from mlx_lm import load, generate
            model, tokenizer = load("mlx-community/Llama-3.2-1B-Instruct-4bit")
            ```
            """.utf8),
            statusCode: 200,
            headers: ["Content-Type": "text/plain"]
        )

        // Create explorer with mock client
        let explorer: CommunityModelsExplorer = CommunityModelsExplorer(httpClient: mockClient)

        // Step 1: Explore community
        let mlxCommunity: ModelCommunity = ModelCommunity.defaultCommunities[0]
        let models: [DiscoveredModel] = try await explorer.exploreCommunity(
            mlxCommunity,
            query: "llama",
            sort: .downloads,
            direction: .descending,
            limit: 10
        )

        #expect(models.count == 1)
        #expect(models[0].id == "mlx-community/Llama-3.2-1B-Instruct-4bit")
        #expect(models[0].detectedBackends.contains(SendableModel.Backend.mlx))
        #expect(models[0].downloads == 25_000)
        #expect(models[0].tags.contains("instruct"))

        // Step 2: Discover specific model details
        let discoveredModel: DiscoveredModel = try await explorer.discoverModel(models[0].id)

        #expect(discoveredModel.files.count == 4)
        #expect(discoveredModel.modelCard != nil)
        #expect(discoveredModel.modelCard?.contains("4GB minimum") == true)
        #expect(discoveredModel.detectedBackends.contains(SendableModel.Backend.mlx))

        // Step 3: Prepare for download
        let sendableModel: SendableModel = try await explorer.prepareForDownload(discoveredModel)

        #expect(sendableModel.location == "mlx-community/Llama-3.2-1B-Instruct-4bit")
        #expect(sendableModel.backend == SendableModel.Backend.mlx)
        #expect(sendableModel.modelType == .language)
        #expect(sendableModel.ramNeeded == 4 * 1_024 * 1_024 * 1_024) // 4GB from model card
    }

    @Test("ModelDownloader integration: Explorer creation and download")
    @MainActor
    func testModelDownloaderIntegration() async {
        let context: TestDownloaderContext = TestDownloaderContext()
        defer { context.cleanup() }

        // Get explorer from downloader
        _ = context.downloader.explorer()

        // Create discovered model
        let discovered: DiscoveredModel = DiscoveredModel(
            id: "test-org/test-model",
            name: "test-model",
            author: "test-org",
            downloads: 1_000,
            likes: 50,
            tags: ["text-generation"],
            lastModified: Date(),
            files: [
                ModelFile(path: "model.gguf", size: 2_000_000_000),
                ModelFile(path: "config.json", size: 1_024)
            ]
        )
        discovered.detectedBackends = [SendableModel.Backend.gguf]

        let fixture: MockHuggingFaceDownloader.FixtureModel = MockHuggingFaceDownloader.FixtureModel(
            modelId: discovered.id,
            backend: .gguf,
            name: discovered.name,
            files: [
                MockHuggingFaceDownloader.FixtureFile(
                    path: "model.gguf",
                    data: Data(repeating: 0x1, count: 64),
                    size: 64
                ),
                MockHuggingFaceDownloader.FixtureFile(
                    path: "config.json",
                    data: Data("{}".utf8),
                    size: 2
                )
            ]
        )
        await context.mockDownloader.registerFixture(fixture)

        // Use the download integration method
        let stream: AsyncThrowingStream<DownloadEvent, Error> = context.downloader.download(discovered)
        var completedInfo: ModelInfo?
        do {
            for try await event in stream {
                if case .completed(let info) = event {
                    completedInfo = info
                }
            }
        } catch {
            Issue.record("Unexpected error: \(error)")
        }

        #expect(completedInfo?.backend == .gguf)
    }

    @Test("Search and download helper method")
    @MainActor
    func testSearchAndDownloadHelper() async {
        let mockClient: CommunityMockHTTPClient = CommunityMockHTTPClient()

        // Mock model discovery (detailed + tree)
        mockClient.responses["/api/models/mlx-community/test-model"] = HTTPClientResponse(
            data: Data("""
            {
                "modelId": "mlx-community/test-model",
                "author": "mlx-community",
                "downloads": 100,
                "likes": 5,
                "tags": ["mlx"],
                "lastModified": "2024-01-01T00:00:00Z",
                "siblings": [
                    {"rfilename": "model.safetensors", "size": 1000},
                    {"rfilename": "config.json", "size": 1024}
                ]
            }
            """.utf8),
            statusCode: 200,
            headers: [:]
        )

        mockClient.responses["/api/models/mlx-community/test-model/tree/main"] = HTTPClientResponse(
            data: Data("""
            [
                {"path": "model.safetensors", "size": 1000, "type": "file"},
                {"path": "config.json", "size": 1024, "type": "file"}
            ]
            """.utf8),
            statusCode: 200,
            headers: [:]
        )

        let explorer: CommunityModelsExplorer = CommunityModelsExplorer(httpClient: mockClient)
        let context: TestDownloaderContext = TestDownloaderContext()
        defer { context.cleanup() }

        let fixture: MockHuggingFaceDownloader.FixtureModel = MockHuggingFaceDownloader.FixtureModel(
            modelId: "mlx-community/test-model",
            backend: .mlx,
            name: "test-model",
            files: [
                MockHuggingFaceDownloader.FixtureFile(
                    path: "model.safetensors",
                    data: Data(repeating: 0x2, count: 32),
                    size: 32
                ),
                MockHuggingFaceDownloader.FixtureFile(
                    path: "config.json",
                    data: Data("{}".utf8),
                    size: 2
                )
            ]
        )
        await context.mockDownloader.registerFixture(fixture)

        // Test searchAndDownload
        let stream: AsyncThrowingStream<DownloadEvent, Error> = await explorer.searchAndDownload(
            modelId: "mlx-community/test-model",
            using: context.downloader
        )
        var completedInfo: ModelInfo?
        do {
            for try await event in stream {
                if case .completed(let info) = event {
                    completedInfo = info
                }
            }
        } catch {
            Issue.record("Unexpected error: \(error)")
        }
        #expect(completedInfo?.backend == .mlx)
    }

    @Test("Paginated search integration")
    @MainActor
    func testPaginatedSearchFlow() async throws {
        let mockClient: CommunityMockHTTPClient = CommunityMockHTTPClient()

        // First page response - should NOT match requests with cursor
        mockClient.responses["api/models?search=test&author=test&sort=downloads"] = HTTPClientResponse(
            data: Data("""
            {
                "models": [
                    {
                        "modelId": "test/model1",
                        "author": "test",
                        "downloads": 1000,
                        "likes": 50,
                        "tags": ["text-generation"],
                        "lastModified": "2024-01-01T00:00:00Z"
                    },
                    {
                        "modelId": "test/model2",
                        "author": "test",
                        "downloads": 900,
                        "likes": 45,
                        "tags": ["text-generation"],
                        "lastModified": "2024-01-02T00:00:00Z"
                    }
                ],
                "nextCursor": "page2"
            }
            """.utf8),
            statusCode: 200,
            headers: [:]
        )

        // Add tree API responses for file: Any information  
        mockClient.responses["/api/models/test/model1/tree/main"] = HTTPClientResponse(
            data: Data("""
            [
                {"path": "model.gguf", "size": 1000000000, "type": "file"}
            ]
            """.utf8),
            statusCode: 200,
            headers: [:]
        )

        mockClient.responses["/api/models/test/model2/tree/main"] = HTTPClientResponse(
            data: Data("""
            [
                {"path": "model.safetensors", "size": 2000000000, "type": "file"},
                {"path": "config.json", "size": 1024, "type": "file"}
            ]
            """.utf8),
            statusCode: 200,
            headers: [:]
        )

        let explorer: CommunityModelsExplorer = CommunityModelsExplorer(httpClient: mockClient)

        // Get first page
        let page1: ModelPage = try await explorer.searchPaginated(
            query: "test",
            author: "test",
            limit: 2
        )

        #expect(page1.models.count == 2)
        #expect(page1.hasNextPage == true)
        #expect(page1.nextPageToken == "page2")

        // Verify backend detection happened
        #expect(page1.models[0].detectedBackends.contains(SendableModel.Backend.gguf))
        #expect(page1.models[1].detectedBackends.contains(SendableModel.Backend.mlx))

        // Setup second page response
        // Track requests
        var requestedURLs: [String] = []
        mockClient.onRequest = { url, _ in
            requestedURLs.append(url.absoluteString)
        }

        // Clear previous responses and set up second page
        mockClient.responses.removeAll()
        mockClient.responses["cursor=page2"] = HTTPClientResponse(
            data: Data("""
            {
                "models": [
                    {
                        "modelId": "test/model3",
                        "author": "test",
                        "downloads": 800,
                        "likes": 40,
                        "tags": ["text-generation"],
                        "lastModified": "2024-01-03T00:00:00Z"
                    }
                ],
                "nextCursor": null
            }
            """.utf8),
            statusCode: 200,
            headers: [:]
        )

        // Add tree API response for third model
        mockClient.responses["/api/models/test/model3/tree/main"] = HTTPClientResponse(
            data: Data("""
            [
                {"path": "model.gguf", "size": 1500000000, "type": "file"}
            ]
            """.utf8),
            statusCode: 200,
            headers: [:]
        )

        // Get second page using cursor
        let page2: ModelPage = try await explorer.searchPaginated(
            query: "test",
            author: "test",
            cursor: page1.nextPageToken,
            limit: 2
        )

        // Verify second page was requested with cursor
        #expect(requestedURLs.contains { $0.contains("cursor=page2") })

        #expect(page2.models.count == 1)
        #expect(page2.hasNextPage == false)
        #expect(page2.models[0].detectedBackends.contains(SendableModel.Backend.gguf))
    }

    @Test("Community filtering with backend support")
    @MainActor
    func testCommunityBackendFiltering() async throws {
        let mockClient: CommunityMockHTTPClient = CommunityMockHTTPClient()

        // Mock response with mixed backend models
        mockClient.responses["/api/models"] = HTTPClientResponse(
            data: Data("""
            [
                {
                    "modelId": "mlx-community/mlx-model",
                    "author": "mlx-community",
                    "downloads": 1000,
                    "likes": 50,
                    "tags": ["text-generation"],
                    "lastModified": "2024-01-01T00:00:00Z"
                },
                {
                    "modelId": "other-user/pytorch-model",
                    "author": "other-user",
                    "downloads": 2000,
                    "likes": 100,
                    "tags": ["text-generation"],
                    "lastModified": "2024-01-02T00:00:00Z"
                }
            ]
            """.utf8),
            statusCode: 200,
            headers: [:]
        )

        // Add tree API responses for file: Any information
        mockClient.responses["/api/models/mlx-community/mlx-model/tree/main"] = HTTPClientResponse(
            data: Data("""
            [
                {"path": "model.safetensors", "size": 1000000000, "type": "file"},
                {"path": "config.json", "size": 1024, "type": "file"}
            ]
            """.utf8),
            statusCode: 200,
            headers: [:]
        )

        mockClient.responses["/api/models/other-user/pytorch-model/tree/main"] = HTTPClientResponse(
            data: Data("""
            [
                {"path": "pytorch_model.bin", "size": 3000000000, "type": "file"}
            ]
            """.utf8),
            statusCode: 200,
            headers: [:]
        )

        let explorer: CommunityModelsExplorer = CommunityModelsExplorer(httpClient: mockClient)

        // Explore MLX community - should filter out unsupported models
        let mlxCommunity: ModelCommunity = ModelCommunity.defaultCommunities[0] // mlx-community
        let results: [DiscoveredModel] = try await explorer.exploreCommunity(mlxCommunity)

        // Should only include the MLX-compatible model
        #expect(results.count == 1)
        #expect(results[0].id == "mlx-community/mlx-model")
        #expect(results[0].detectedBackends.contains(SendableModel.Backend.mlx))

        // The pytorch model should be filtered out as it doesn't support MLX backend
    }

    @Test("Error handling: Model not found")
    func testModelNotFoundError() async {
        let mockClient: CommunityMockHTTPClient = CommunityMockHTTPClient()

        // Mock 404 response
        mockClient.responses["/api/models/nonexistent/model/tree/main"] = HTTPClientResponse(
            data: Data(),
            statusCode: 404,
            headers: [:]
        )

        let explorer: CommunityModelsExplorer = CommunityModelsExplorer(httpClient: mockClient)

        do {
            _ = try await explorer.discoverModel("nonexistent/model")
            Issue.record("Expected HuggingFaceError.repositoryNotFound")
        } catch let error as HuggingFaceError {
            switch error {
            case .repositoryNotFound:
                // Expected error
                break

            default:
                Issue.record("Unexpected error type: \(error)")
            }
        } catch {
            Issue.record("Unexpected error: \(error)")
        }
    }

    @Test("Error handling: No supported backends")
    @MainActor
    func testNoSupportedBackendsError() async throws {
        let mockClient: CommunityMockHTTPClient = CommunityMockHTTPClient()

        // Mock model with only unsupported files
        mockClient.responses["/api/models/test/unsupported-model"] = HTTPClientResponse(
            data: Data("""
            {
                "modelId": "test/unsupported-model",
                "author": "test",
                "downloads": 0,
                "likes": 0,
                "tags": ["pytorch"],
                "lastModified": "2024-01-01T00:00:00Z",
                "siblings": [
                    {"rfilename": "pytorch_model.bin", "size": 5000000000},
                    {"rfilename": "model.h5", "size": 3000000000}
                ]
            }
            """.utf8),
            statusCode: 200,
            headers: [:]
        )

        let explorer: CommunityModelsExplorer = CommunityModelsExplorer(httpClient: mockClient)

        let model: DiscoveredModel = try await explorer.discoverModel("test/unsupported-model")

        // Model should be discovered but have no supported backends
        #expect(model.detectedBackends.isEmpty)

        // Attempting to prepare for download should fail
        do {
            _ = try await explorer.prepareForDownload(model)
            Issue.record("Expected HuggingFaceError.unsupportedFormat")
        } catch HuggingFaceError.unsupportedFormat {
            // Expected error
        } catch {
            Issue.record("Unexpected error: \(error)")
        }
    }

    @Test("Model type inference from tags")
    @MainActor
    func testModelTypeInference() async throws {
        let explorer: CommunityModelsExplorer = CommunityModelsExplorer()

        // Test different model types
        struct TestCase {
            let tags: [String]
            let name: String
            let expectedType: SendableModel.ModelType
        }

        let testCases: [TestCase] = [
            TestCase(tags: ["stable-diffusion", "text-to-image"], name: "sd-model", expectedType: .diffusion),
            TestCase(tags: ["stable-diffusion-xl", "sdxl"], name: "sdxl-model", expectedType: .diffusionXL),
            TestCase(tags: ["vision", "multimodal"], name: "vision-model", expectedType: .visualLanguage),
            TestCase(tags: ["text-generation", "qwen"], name: "Qwen-model", expectedType: .flexibleThinker),
            TestCase(tags: ["text-generation", "language-model"], name: "llama-70b", expectedType: .deepLanguage),
            TestCase(tags: ["text-generation"], name: "small-model", expectedType: .language)
        ]

        for testCase in testCases {
            let model: DiscoveredModel = DiscoveredModel(
                id: "test/\(testCase.name)",
                name: testCase.name,
                author: "test",
                downloads: 1_000,
                likes: 50,
                tags: testCase.tags,
                lastModified: Date(),
                files: [ModelFile(path: "model.bin", size: 1_000_000_000)]
            )
            model.detectedBackends = [SendableModel.Backend.mlx]

            #expect(model.inferredModelType == testCase.expectedType)

            let sendable: SendableModel = try await explorer.prepareForDownload(model)
            #expect(sendable.modelType == testCase.expectedType)
        }
    }

    @Test("Search by multiple tags")
    @MainActor
    func testMultiTagSearch() async throws {
        let mockClient: CommunityMockHTTPClient = CommunityMockHTTPClient()

        var capturedURLs: [URL] = []
        mockClient.onRequest = { url, _ in
            capturedURLs.append(url)
        }

        mockClient.responses["/api/models"] = HTTPClientResponse(
            data: Data("""
            [
                {
                    "modelId": "test/multi-tag-model",
                    "author": "test",
                    "downloads": 1000,
                    "likes": 50,
                    "tags": ["text-generation", "llama", "instruct", "4bit"],
                    "lastModified": "2024-01-01T00:00:00Z"
                }
            ]
            """.utf8),
            statusCode: 200,
            headers: [:]
        )

        // Add tree API response for file sizes
        mockClient.responses["/api/models/test/multi-tag-model/tree/main"] = HTTPClientResponse(
            data: Data("""
            [
                {"path": "model.gguf", "size": 1000000000, "type": "file"},
                {"path": "config.json", "size": 1024, "type": "file"}
            ]
            """.utf8),
            statusCode: 200,
            headers: [:]
        )

        let explorer: CommunityModelsExplorer = CommunityModelsExplorer(httpClient: mockClient)

        let results: [DiscoveredModel] = try await explorer.searchByTags(
            ["text-generation", "llama", "instruct", "4bit"],
            community: ModelCommunity.defaultCommunities[1], // coreml-community
            sort: .likes,
            limit: 20
        )

        // CoreML community won't match GGUF models, so results should be empty
        #expect(results.isEmpty)

        // Find the search API URL (should contain query parameters)
        let searchURL: URL? = capturedURLs.first { url in
            url.path == "/api/models" && url.query != nil
        }

        #expect(searchURL?.absoluteString.contains("tags=text-generation") == true)
        #expect(searchURL?.absoluteString.contains("tags=llama") == true)
        #expect(searchURL?.absoluteString.contains("tags=instruct") == true)
        #expect(searchURL?.absoluteString.contains("tags=4bit") == true)
        #expect(searchURL?.absoluteString.contains("author=coreml-community") == true)
        #expect(searchURL?.absoluteString.contains("sort=likes") == true)
        #expect(searchURL?.absoluteString.contains("limit=20") == true)
    }
}
