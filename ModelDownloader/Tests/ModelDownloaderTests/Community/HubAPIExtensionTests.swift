import Abstractions
import Foundation
@testable import ModelDownloader
import Testing

@Suite("HubAPI Community Extension Tests")
struct HubAPIExtensionTests {
    @Test("Search models in community")
    @MainActor
    func testSearchModels() async throws {
        // Create mock client that returns search results
        let mockClient: CommunityMockHTTPClient = CommunityMockHTTPClient()
        mockClient.responses["/api/models"] = HTTPClientResponse(
            data: Data("""
            [
                {
                    "modelId": "mlx-community/Llama-3.2-1B-Instruct-4bit",
                    "author": "mlx-community",
                    "downloads": 15000,
                    "likes": 250,
                    "tags": ["text-generation", "llama", "instruct"],
                    "lastModified": "2024-01-15T10:00:00Z",
                    "siblings": [
                        {"rfilename": "model.safetensors", "size": 1073741824},
                        {"rfilename": "config.json", "size": 1024},
                        {"rfilename": "tokenizer.json", "size": 2048}
                    ]
                },
                {
                    "modelId": "mlx-community/Qwen2.5-7B-Instruct-4bit",
                    "author": "mlx-community",
                    "downloads": 8000,
                    "likes": 150,
                    "tags": ["text-generation", "qwen", "flexible-thinker"],
                    "lastModified": "2024-01-10T10:00:00Z",
                    "siblings": [
                        {"rfilename": "model.safetensors", "size": 7516192768},
                        {"rfilename": "config.json", "size": 1024}
                    ]
                }
            ]
            """.utf8),
            statusCode: 200,
            headers: [:]
        )

        // Add tree API responses for file: Any information
        mockClient.responses["/api/models/mlx-community/Llama-3.2-1B-Instruct-4bit/tree/main"] = HTTPClientResponse(
            data: Data("""
            [
                {"path": "model.safetensors", "size": 1073741824, "type": "file"},
                {"path": "config.json", "size": 1024, "type": "file"},
                {"path": "tokenizer.json", "size": 2048, "type": "file"}
            ]
            """.utf8),
            statusCode: 200,
            headers: [:]
        )

        mockClient.responses["/api/models/mlx-community/Qwen2.5-7B-Instruct-4bit/tree/main"] = HTTPClientResponse(
            data: Data("""
            [
                {"path": "model.safetensors", "size": 7516192768, "type": "file"},
                {"path": "config.json", "size": 1024, "type": "file"}
            ]
            """.utf8),
            statusCode: 200,
            headers: [:]
        )

        let hubAPI: HubAPI = HubAPI(httpClient: mockClient)

        // Test basic search
        let results: [DiscoveredModel] = try await hubAPI.searchModels(
            query: "text-generation",
            author: "mlx-community",
            limit: 10
        )

        #expect(results.count == 2)
        #expect(results[0].id == "mlx-community/Llama-3.2-1B-Instruct-4bit")
        #expect(results[0].author == "mlx-community")
        #expect(results[0].downloads == 15_000)
        #expect(results[0].likes == 250)
        #expect(results[0].files.count == 3)
        #expect(results[0].totalSize == 1_073_741_824 + 1_024 + 2_048)

        #expect(results[1].id == "mlx-community/Qwen2.5-7B-Instruct-4bit")
        #expect(results[1].author == "mlx-community")
        #expect(results[1].files.count == 2)
    }

    @Test("Search with sort options")
    @MainActor
    func testSearchWithSort() async throws {
        let mockClient: CommunityMockHTTPClient = CommunityMockHTTPClient()
        let hubAPI: HubAPI = HubAPI(httpClient: mockClient)

        // Capture request URL to verify sort parameter
        var capturedURL: URL?
        mockClient.onRequest = { url, _ in
            capturedURL = url
        }

        mockClient.responses["/api/models"] = HTTPClientResponse(
            data: Data("[]".utf8),
            statusCode: 200,
            headers: [:]
        )

        // Test different sort options
        _ = try await hubAPI.searchModels(
            query: "llama",
            sort: .downloads,
            direction: .descending
        )

        #expect(capturedURL?.absoluteString.contains("sort=downloads") == true)
        #expect(capturedURL?.absoluteString.contains("direction=-1") == true)

        // Test ascending sort
        _ = try await hubAPI.searchModels(
            query: "llama",
            sort: .likes,
            direction: .ascending
        )

        #expect(capturedURL?.absoluteString.contains("sort=likes") == true)
        #expect(capturedURL?.absoluteString.contains("direction=1") == true)
    }

    @Test("Search with pagination")
    @MainActor
    func testSearchPagination() async throws {
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
                        "lastModified": "2024-01-01T00:00:00Z",
                        "siblings": []
                    }
                ],
                "nextCursor": "eyJuZXh0IjogInBhZ2UyIn0="
            }
            """.utf8),
            statusCode: 200,
            headers: [:]
        )

        // Add tree API response for pagination test
        mockClient.responses["/api/models/test/model1/tree/main"] = HTTPClientResponse(
            data: Data("[]".utf8),
            statusCode: 200,
            headers: [:]
        )

        let hubAPI: HubAPI = HubAPI(httpClient: mockClient)

        let page: ModelPage = try await hubAPI.searchModelsPaginated(
            query: "test",
            limit: 20
        )

        #expect(page.models.count == 1)
        #expect(page.nextPageToken == "eyJuZXh0IjogInBhZ2UyIn0=")
        #expect(page.hasNextPage == true)
    }

    @Test("Get model card")
    @MainActor
    func testGetModelCard() async throws {
        let mockClient: CommunityMockHTTPClient = CommunityMockHTTPClient()
        let modelCard: String = """
        # Model Card for Llama-3.2-1B-Instruct

        This model requires 8GB RAM minimum.

        ## Model Details
        - Architecture: Llama
        - Parameters: 1B
        - Quantization: 4-bit
        """

        mockClient.responses["/mlx-community/Llama-3.2-1B-Instruct-4bit/raw/main/README.md"] = HTTPClientResponse(
            data: Data(modelCard.utf8),
            statusCode: 200,
            headers: ["Content-Type": "text/plain"]
        )

        let hubAPI: HubAPI = HubAPI(httpClient: mockClient)

        let retrievedCard: String? = try await hubAPI.getModelCard(
            modelId: "mlx-community/Llama-3.2-1B-Instruct-4bit"
        )

        #expect(retrievedCard == modelCard)
    }

    @Test("Handle model card not found")
    @MainActor
    func testModelCardNotFound() async throws {
        let mockClient: CommunityMockHTTPClient = CommunityMockHTTPClient()
        mockClient.responses["/test/model/raw/main/README.md"] = HTTPClientResponse(
            data: Data(),
            statusCode: 404,
            headers: [:]
        )

        let hubAPI: HubAPI = HubAPI(httpClient: mockClient)

        let card: String? = try await hubAPI.getModelCard(modelId: "test/model")
        #expect(card == nil)
    }

    @Test("Handle search API errors")
    @MainActor
    func testSearchAPIErrors() async throws {
        let mockClient: CommunityMockHTTPClient = CommunityMockHTTPClient()

        // Test 401 Unauthorized
        mockClient.responses["/api/models"] = HTTPClientResponse(
            data: Data(),
            statusCode: 401,
            headers: [:]
        )

        let hubAPI: HubAPI = HubAPI(httpClient: mockClient)

        do {
            _ = try await hubAPI.searchModels(query: "private-model")
            Issue.record("Expected HuggingFaceError.authenticationRequired")
        } catch HuggingFaceError.authenticationRequired {
            // Expected error
        } catch {
            Issue.record("Unexpected error: \(error)")
        }

        // Test 500 Server Error
        mockClient.responses["/api/models"] = HTTPClientResponse(
            data: Data(),
            statusCode: 500,
            headers: [:]
        )

        do {
            _ = try await hubAPI.searchModels(query: "test")
            Issue.record("Expected HuggingFaceError.httpError")
        } catch HuggingFaceError.httpError(let statusCode) {
            #expect(statusCode == 500)
        } catch {
            Issue.record("Unexpected error: \(error)")
        }
    }

    @Test("Filter search by tags")
    @MainActor
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

        let hubAPI: HubAPI = HubAPI(httpClient: mockClient)

        _ = try await hubAPI.searchModels(
            tags: ["text-generation", "llama", "instruct"]
        )

        #expect(capturedURL?.absoluteString.contains("tags=text-generation") == true)
        #expect(capturedURL?.absoluteString.contains("tags=llama") == true)
        #expect(capturedURL?.absoluteString.contains("tags=instruct") == true)
    }
}
