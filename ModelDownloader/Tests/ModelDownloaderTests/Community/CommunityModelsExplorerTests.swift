import Abstractions
import Foundation
@testable import ModelDownloader
import Testing

extension APITests {
    @Test("Explore community with search")
    @MainActor
    func testExploreCommunity() async throws {
        // Setup mock dependencies
        let mockClient: CommunityMockHTTPClient = CommunityMockHTTPClient()
        mockClient.responses["/api/models"] = HTTPClientResponse(
            data: Data("""
            [
                {
                    "modelId": "mlx-community/Llama-3.2-1B-4bit",
                    "author": "mlx-community",
                    "downloads": 10000,
                    "likes": 200,
                    "tags": ["llama", "text-generation"],
                    "lastModified": "2024-01-20T10:00:00Z"
                }
            ]
            """.utf8),
            statusCode: 200,
            headers: [:]
        )

        // Add tree API response for file: Any information
        mockClient.responses["/api/models/mlx-community/Llama-3.2-1B-4bit/tree/main"] = HTTPClientResponse(
            data: Data("""
            [
                {"path": "model.safetensors", "size": 1073741824, "type": "file"},
                {"path": "config.json", "size": 1024, "type": "file"}
            ]
            """.utf8),
            statusCode: 200,
            headers: [:]
        )

        let explorer: CommunityModelsExplorer = CommunityModelsExplorer(httpClient: mockClient)

        // Test exploration
        let mlxCommunity: ModelCommunity = ModelCommunity.defaultCommunities[0] // mlx-community
        let results: [DiscoveredModel] = try await explorer.exploreCommunity(
            mlxCommunity,
            query: "llama",
            sort: .downloads,
            limit: 10
        )

        #expect(results.count == 1)
        #expect(results[0].id == "mlx-community/Llama-3.2-1B-4bit")
        // Backends are detected from file patterns - safetensors + config.json = MLX
        #expect(results[0].detectedBackends.contains(SendableModel.Backend.mlx))
        #expect(results[0].primaryBackend == SendableModel.Backend.mlx)
    }

    @Test("Discover specific model")
    @MainActor
    func testDiscoverModel() async throws {
        let mockClient: CommunityMockHTTPClient = CommunityMockHTTPClient()

        // Mock the main model info API response
        mockClient.responses["/api/models/mlx-community/test-model"] = HTTPClientResponse(
            data: Data("""
            {
                "_id": "mlx-community/test-model",
                "id": "mlx-community/test-model",
                "author": "mlx-community",
                "sha": "main",
                "downloads": 12345,
                "likes": 50,
                "tags": ["text-generation", "mlx"],
                "siblings": [
                    {"rfilename": "model.safetensors", "size": 2000000000},
                    {"rfilename": "config.json", "size": 1024},
                    {"rfilename": "tokenizer.json", "size": 2048}
                ]
            }
            """.utf8),
            statusCode: 200,
            headers: [:]
        )

        // Mock model files response - HuggingFace API uses /api/models/<id>/tree/main
        mockClient.responses["/api/models/mlx-community/test-model/tree/main"] = HTTPClientResponse(
            data: Data("""
            [
                {"path": "model.safetensors", "size": 2000000000, "type": "file"},
                {"path": "config.json", "size": 1024, "type": "file"},
                {"path": "tokenizer.json", "size": 2048, "type": "file"}
            ]
            """.utf8),
            statusCode: 200,
            headers: [:]
        )

        // Mock model card response
        mockClient.responses["/mlx-community/test-model/raw/main/README.md"] = HTTPClientResponse(
            data: Data("""
            # Test Model
            This model requires 8GB RAM.
            """.utf8),
            statusCode: 200,
            headers: ["Content-Type": "text/plain"]
        )

        let explorer: CommunityModelsExplorer = CommunityModelsExplorer(httpClient: mockClient)

        let model: DiscoveredModel = try await explorer.discoverModel("mlx-community/test-model")

        #expect(model.id == "mlx-community/test-model")
        #expect(model.files.count == 3)
        #expect(model.modelCard?.contains("8GB RAM") == true)
        #expect(model.detectedBackends.contains(SendableModel.Backend.mlx))
    }

    @Test("Get default communities")
    func testGetDefaultCommunities() {
        let explorer: CommunityModelsExplorer = CommunityModelsExplorer()
        let communities: [ModelCommunity] = explorer.getDefaultCommunities()

        #expect(communities.count == 4)
        #expect(communities.contains { $0.id == "mlx-community" })
        #expect(communities.contains { $0.id == "coreml-community" })
    }

    @Test("Convert to SendableModel")
    @MainActor
    func testConvertToSendableModel() async throws {
        let explorer: CommunityModelsExplorer = CommunityModelsExplorer()

        let discovered: DiscoveredModel = DiscoveredModel(
            id: "test-org/test-model",
            name: "test-model",
            author: "test-org",
            downloads: 1_000,
            likes: 50,
            tags: ["text-generation"],
            lastModified: Date(),
            files: [
                ModelFile(path: "model.safetensors", size: 8_000_000_000),
                ModelFile(path: "config.json", size: 1_024)
            ]
        )
        discovered.modelCard = "This model requires 16GB RAM"
        discovered.detectedBackends = [SendableModel.Backend.mlx]

        let sendable: SendableModel = try await explorer.prepareForDownload(discovered)

        #expect(sendable.location == "test-org/test-model")
        #expect(sendable.backend == SendableModel.Backend.mlx)
        #expect(sendable.ramNeeded == 16 * 1_024 * 1_024 * 1_024) // 16GB
    }

    @Test("Search models with pagination")
    func testSearchWithPagination() async throws {
        let mockClient: CommunityMockHTTPClient = CommunityMockHTTPClient()
        mockClient.responses["/api/models"] = HTTPClientResponse(
            data: Data("""
            {
                "models": [
                    {
                        "modelId": "test/model1",
                        "author": "test",
                        "downloads": 100,
                        "likes": 10,
                        "tags": ["test"],
                        "lastModified": "2024-01-01T00:00:00Z"
                    }
                ],
                "nextCursor": "page2token"
            }
            """.utf8),
            statusCode: 200,
            headers: [:]
        )

        // Add tree API response for file: Any information  
        mockClient.responses["/api/models/test/model1/tree/main"] = HTTPClientResponse(
            data: Data("""
            [
                {"path": "model.bin", "size": 1000000000, "type": "file"}
            ]
            """.utf8),
            statusCode: 200,
            headers: [:]
        )

        let explorer: CommunityModelsExplorer = CommunityModelsExplorer(httpClient: mockClient)

        let page: ModelPage = try await explorer.searchPaginated(
            query: "test",
            author: "test",
            limit: 20
        )

        #expect(page.models.count == 1)
        #expect(page.hasNextPage == true)
        #expect(page.nextPageToken == "page2token")
    }

    @Test("Handle model not found")
    func testModelNotFound() async throws {
        let mockClient: CommunityMockHTTPClient = CommunityMockHTTPClient()
        mockClient.responses["/nonexistent/model/api"] = HTTPClientResponse(
            data: Data(),
            statusCode: 404,
            headers: [:]
        )

        let explorer: CommunityModelsExplorer = CommunityModelsExplorer(httpClient: mockClient)

        do {
            _ = try await explorer.discoverModel("nonexistent/model")
            Issue.record("Expected error for non-existent model")
        } catch HuggingFaceError.repositoryNotFound {
            // Expected error
        } catch {
            Issue.record("Unexpected error: \(error)")
        }
    }

    @Test("Search by tags")
    func testSearchByTags() async throws {
        let mockClient: CommunityMockHTTPClient = CommunityMockHTTPClient()
        var capturedURL: URL?
        mockClient.onRequest = { url, _ in
            capturedURL = url
        }

        mockClient.responses["/api/models"] = HTTPClientResponse(
            data: Data("[]".utf8),
            statusCode: 200,
            headers: [:]
        )

        let explorer: CommunityModelsExplorer = CommunityModelsExplorer(httpClient: mockClient)

        let mlxCommunity: ModelCommunity = ModelCommunity.defaultCommunities[0]
        _ = try await explorer.searchByTags(
            ["text-generation", "llama", "4bit"],
            community: mlxCommunity
        )

        #expect(capturedURL?.absoluteString.contains("author=mlx-community") == true)
        #expect(capturedURL?.absoluteString.contains("tags=text-generation") == true)
        #expect(capturedURL?.absoluteString.contains("tags=llama") == true)
        #expect(capturedURL?.absoluteString.contains("tags=4bit") == true)
    }

    @Test("Explore community returns models with license information")
    @MainActor
    func testExploreCommunityWithLicenses() async throws {
        // Setup mock dependencies
        let mockClient: CommunityMockHTTPClient = CommunityMockHTTPClient()
        mockClient.responses["/api/models"] = HTTPClientResponse(
            data: Data("""
            [
                {
                    "modelId": "mlx-community/Llama-3.2-1B-4bit",
                    "author": "mlx-community",
                    "downloads": 10000,
                    "likes": 200,
                    "tags": ["llama", "text-generation"],
                    "lastModified": "2024-01-20T10:00:00Z",
                    "cardData": {
                        "license": "llama3.2"
                    }
                },
                {
                    "modelId": "mlx-community/phi-2-mlx",
                    "author": "mlx-community",
                    "downloads": 5000,
                    "likes": 100,
                    "tags": ["text-generation"],
                    "lastModified": "2024-01-20T10:00:00Z",
                    "cardData": {
                        "license": "mit"
                    }
                }
            ]
            """.utf8),
            statusCode: 200,
            headers: [:]
        )

        // Add tree API responses for file: Any information
        mockClient.responses["/api/models/mlx-community/Llama-3.2-1B-4bit/tree/main"] = HTTPClientResponse(
            data: Data("""
            [
                {"path": "model.safetensors", "size": 1073741824, "type": "file"},
                {"path": "config.json", "size": 1024, "type": "file"}
            ]
            """.utf8),
            statusCode: 200,
            headers: [:]
        )

        mockClient.responses["/api/models/mlx-community/phi-2-mlx/tree/main"] = HTTPClientResponse(
            data: Data("""
            [
                {"path": "model.safetensors", "size": 500000000, "type": "file"},
                {"path": "config.json", "size": 1024, "type": "file"}
            ]
            """.utf8),
            statusCode: 200,
            headers: [:]
        )

        let explorer: CommunityModelsExplorer = CommunityModelsExplorer(httpClient: mockClient)
        let mlxCommunity: ModelCommunity = ModelCommunity.defaultCommunities[0] // mlx-community

        let results: [DiscoveredModel] = try await explorer.exploreCommunity(
            mlxCommunity,
            query: nil,
            sort: .downloads,
            limit: 10
        )

        #expect(results.count == 2)

        // Check first model has llama license
        let llamaModel: DiscoveredModel = results[0]
        #expect(llamaModel.license == "llama3.2")
        #expect(llamaModel.licenseUrl == "https://llama.meta.com/llama3_2/license/")

        // Check second model has MIT license
        let phiModel: DiscoveredModel = results[1]
        #expect(phiModel.license == "mit")
        #expect(phiModel.licenseUrl == "https://opensource.org/licenses/MIT")
    }

    @Test("Models without license have nil license fields")
    @MainActor
    func testModelsWithoutLicense() async throws {
        let mockClient: CommunityMockHTTPClient = CommunityMockHTTPClient()
        mockClient.responses["/api/models"] = HTTPClientResponse(
            data: Data("""
            [
                {
                    "modelId": "mlx-community/no-license-model",
                    "author": "mlx-community",
                    "downloads": 500,
                    "likes": 25,
                    "tags": ["text-generation"],
                    "lastModified": "2024-01-20T10:00:00Z"
                }
            ]
            """.utf8),
            statusCode: 200,
            headers: [:]
        )

        // Add tree API response for file: Any information
        mockClient.responses["/api/models/mlx-community/no-license-model/tree/main"] = HTTPClientResponse(
            data: Data("""
            [
                {"path": "model.safetensors", "size": 100000000, "type": "file"},
                {"path": "config.json", "size": 1024, "type": "file"}
            ]
            """.utf8),
            statusCode: 200,
            headers: [:]
        )

        let explorer: CommunityModelsExplorer = CommunityModelsExplorer(httpClient: mockClient)
        let mlxCommunity: ModelCommunity = ModelCommunity.defaultCommunities[0] // mlx-community
        let results: [DiscoveredModel] = try await explorer.exploreCommunity(
            mlxCommunity,
            query: nil
        )

        #expect(results.count == 1)
        let model: DiscoveredModel = results[0]
        #expect(model.license == nil)
        #expect(model.licenseUrl == nil)
    }

    @Test("Paginated search preserves license information")
    @MainActor
    func testPaginatedSearchWithLicenses() async throws {
        let mockClient: CommunityMockHTTPClient = CommunityMockHTTPClient()
        mockClient.responses["/api/models"] = HTTPClientResponse(
            data: Data("""
            {
                "models": [
                    {
                        "modelId": "test-org/model1",
                        "author": "test-org",
                        "downloads": 1000,
                        "likes": 50,
                        "tags": ["text-generation"],
                        "lastModified": "2024-01-20T10:00:00Z",
                        "cardData": {
                            "license": "gpl-3.0"
                        }
                    }
                ],
                "nextCursor": "next-page"
            }
            """.utf8),
            statusCode: 200,
            headers: [:]
        )

        // Add tree API response for file: Any information  
        mockClient.responses["/api/models/test-org/model1/tree/main"] = HTTPClientResponse(
            data: Data("""
            [
                {"path": "model.bin", "size": 1000000000, "type": "file"}
            ]
            """.utf8),
            statusCode: 200,
            headers: [:]
        )

        let explorer: CommunityModelsExplorer = CommunityModelsExplorer(httpClient: mockClient)
        let page: ModelPage = try await explorer.searchPaginated(
            query: "test",
            limit: 1
        )

        #expect(page.models.count == 1)
        #expect(page.hasNextPage == true)

        let model: DiscoveredModel = page.models[0]
        #expect(model.license == "gpl-3.0")
        #expect(model.licenseUrl == "https://www.gnu.org/licenses/gpl-3.0.html")
    }
}
