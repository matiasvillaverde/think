import Abstractions
import Foundation
@testable import ModelDownloader
import Testing

@Suite("HubAPIExtension License Tests", .serialized)
struct HubAPIExtensionLicenseTests {
    @Test("Parse API response with license in cardData")
    @MainActor
    func testParseResponseWithLicense() async throws {
        let mockResponseString: String = """
        [
            {
                "modelId": "test-org/test-model",
                "author": "test-org",
                "downloads": 1000,
                "likes": 50,
                "tags": ["text-generation"],
                "lastModified": "2024-01-01T00:00:00Z",
                "siblings": [
                    {"rfilename": "model.safetensors", "size": 1000000}
                ],
                "cardData": {
                    "license": "apache-2.0"
                }
            }
        ]
        """

        let mockResponse: Data = Data(mockResponseString.utf8)

        let mockHTTPClient: CommunityMockHTTPClient = CommunityMockHTTPClient()
        mockHTTPClient.responses["/api/models"] = HTTPClientResponse(
            data: mockResponse,
            statusCode: 200,
            headers: [:]
        )

        let hubAPI: HubAPI = HubAPI(httpClient: mockHTTPClient)
        let models: [DiscoveredModel] = try await hubAPI.searchModels()

        #expect(models.count == 1)
        let model: DiscoveredModel = models[0]
        #expect(model.license == "apache-2.0")
        #expect(model.licenseUrl == "https://www.apache.org/licenses/LICENSE-2.0")
    }

    @Test("Parse API response without cardData")
    @MainActor
    func testParseResponseWithoutCardData() async throws {
        let mockResponseString: String = """
        [
            {
                "modelId": "test-org/test-model",
                "author": "test-org",
                "downloads": 1000,
                "likes": 50,
                "tags": ["text-generation"],
                "lastModified": "2024-01-01T00:00:00Z",
                "siblings": [
                    {"rfilename": "model.safetensors", "size": 1000000}
                ]
            }
        ]
        """

        let mockResponse: Data = Data(mockResponseString.utf8)

        let mockHTTPClient: CommunityMockHTTPClient = CommunityMockHTTPClient()
        mockHTTPClient.responses["/api/models"] = HTTPClientResponse(
            data: mockResponse,
            statusCode: 200,
            headers: [:]
        )

        let hubAPI: HubAPI = HubAPI(httpClient: mockHTTPClient)
        let models: [DiscoveredModel] = try await hubAPI.searchModels()

        #expect(models.count == 1)
        let model: DiscoveredModel = models[0]
        #expect(model.license == nil)
        #expect(model.licenseUrl == nil)
    }

    @Test("Parse API response with null license in cardData")
    @MainActor
    func testParseResponseWithNullLicense() async throws {
        let mockResponseString: String = """
        [
            {
                "modelId": "test-org/test-model",
                "author": "test-org",
                "downloads": 1000,
                "likes": 50,
                "tags": ["text-generation"],
                "lastModified": "2024-01-01T00:00:00Z",
                "siblings": [
                    {"rfilename": "model.safetensors", "size": 1000000}
                ],
                "cardData": {
                    "license": null
                }
            }
        ]
        """

        let mockResponse: Data = Data(mockResponseString.utf8)

        let mockHTTPClient: CommunityMockHTTPClient = CommunityMockHTTPClient()
        mockHTTPClient.responses["/api/models"] = HTTPClientResponse(
            data: mockResponse,
            statusCode: 200,
            headers: [:]
        )

        let hubAPI: HubAPI = HubAPI(httpClient: mockHTTPClient)
        let models: [DiscoveredModel] = try await hubAPI.searchModels()

        #expect(models.count == 1)
        let model: DiscoveredModel = models[0]
        #expect(model.license == nil)
        #expect(model.licenseUrl == nil)
    }

    @Test("Parse API response with unknown license")
    @MainActor
    func testParseResponseWithUnknownLicense() async throws {
        let mockResponseString: String = """
        [
            {
                "modelId": "test-org/test-model",
                "author": "test-org",
                "downloads": 1000,
                "likes": 50,
                "tags": ["text-generation"],
                "lastModified": "2024-01-01T00:00:00Z",
                "siblings": [
                    {"rfilename": "model.safetensors", "size": 1000000}
                ],
                "cardData": {
                    "license": "custom-proprietary-license"
                }
            }
        ]
        """

        let mockResponse: Data = Data(mockResponseString.utf8)

        let mockHTTPClient: CommunityMockHTTPClient = CommunityMockHTTPClient()
        mockHTTPClient.responses["/api/models"] = HTTPClientResponse(
            data: mockResponse,
            statusCode: 200,
            headers: [:]
        )

        let hubAPI: HubAPI = HubAPI(httpClient: mockHTTPClient)
        let models: [DiscoveredModel] = try await hubAPI.searchModels()

        #expect(models.count == 1)
        let model: DiscoveredModel = models[0]
        #expect(model.license == "custom-proprietary-license")
        #expect(model.licenseUrl == nil) // No URL mapping for unknown license
    }

    @Test("Parse paginated API response with licenses")
    @MainActor
    func testParsePaginatedResponseWithLicenses() async throws {
        let mockResponseString: String = """
        {
            "models": [
                {
                    "modelId": "test-org/model1",
                    "author": "test-org",
                    "downloads": 1000,
                    "likes": 50,
                    "tags": ["text-generation"],
                    "lastModified": "2024-01-01T00:00:00Z",
                    "siblings": [],
                    "cardData": {
                        "license": "mit"
                    }
                },
                {
                    "modelId": "test-org/model2",
                    "author": "test-org",
                    "downloads": 2000,
                    "likes": 100,
                    "tags": ["text-generation"],
                    "lastModified": "2024-01-02T00:00:00Z",
                    "siblings": [],
                    "cardData": {
                        "license": "llama3"
                    }
                }
            ],
            "nextCursor": "next-page-token"
        }
        """

        let mockResponse: Data = Data(mockResponseString.utf8)

        let mockHTTPClient: CommunityMockHTTPClient = CommunityMockHTTPClient()
        mockHTTPClient.responses["/api/models"] = HTTPClientResponse(
            data: mockResponse,
            statusCode: 200,
            headers: [:]
        )

        let hubAPI: HubAPI = HubAPI(httpClient: mockHTTPClient)
        let page: ModelPage = try await hubAPI.searchModelsPaginated()

        #expect(page.models.count == 2)
        #expect(page.hasNextPage == true)
        #expect(page.nextPageToken == "next-page-token")

        let model1: DiscoveredModel = page.models[0]
        #expect(model1.license == "mit")
        #expect(model1.licenseUrl == "https://opensource.org/licenses/MIT")

        let model2: DiscoveredModel = page.models[1]
        #expect(model2.license == "llama3")
        #expect(model2.licenseUrl == "https://llama.meta.com/llama3/license/")
    }

    @Test("Preserve existing metadata when adding license")
    @MainActor
    func testPreserveExistingMetadata() async throws {
        // This test ensures we don't overwrite other metadata when adding license info
        let mockResponseString: String = """
        [
            {
                "modelId": "test-org/test-model",
                "author": "test-org",
                "downloads": 1000,
                "likes": 50,
                "tags": ["text-generation"],
                "lastModified": "2024-01-01T00:00:00Z",
                "siblings": [],
                "cardData": {
                    "license": "gpl-3.0"
                }
            }
        ]
        """

        let mockResponse: Data = Data(mockResponseString.utf8)

        let mockHTTPClient: CommunityMockHTTPClient = CommunityMockHTTPClient()
        mockHTTPClient.responses["/api/models"] = HTTPClientResponse(
            data: mockResponse,
            statusCode: 200,
            headers: [:]
        )

        let hubAPI: HubAPI = HubAPI(httpClient: mockHTTPClient)
        let models: [DiscoveredModel] = try await hubAPI.searchModels()

        #expect(models.count == 1)
        let model: DiscoveredModel = models[0]

        // Should have license properties
        #expect(model.license == "gpl-3.0")
        #expect(model.licenseUrl == "https://www.gnu.org/licenses/gpl-3.0.html")

        // Metadata should be empty now that license is not stored there
        #expect(model.metadata.isEmpty)
    }
}
