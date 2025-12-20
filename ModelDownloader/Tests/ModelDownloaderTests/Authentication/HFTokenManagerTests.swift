import Foundation
@testable import ModelDownloader
import Testing

@Test("HFTokenManager should discover token from HF_TOKEN environment variable")
internal func testTokenDiscoveryFromHFTokenEnv() async {
    let mockEnvironment: [String: String] = ["HF_TOKEN": "test_token_hf"]
    let mockFileManager: MockHFFileManager = MockHFFileManager()
    let mockHTTPClient: MockHTTPClient = MockHTTPClient()

    let tokenManager: HFTokenManager = HFTokenManager(
        environment: mockEnvironment,
        fileManager: mockFileManager,
        httpClient: mockHTTPClient
    )

    let token: String? = await tokenManager.getToken()
    #expect(token == "test_token_hf")
}

@Test("HFTokenManager should return nil when no token found")
internal func testNoTokenFound() async {
    let mockEnvironment: [String: String] = [:]
    let mockFileManager: MockHFFileManager = MockHFFileManager()
    let mockHTTPClient: MockHTTPClient = MockHTTPClient()

    let tokenManager: HFTokenManager = HFTokenManager(
        environment: mockEnvironment,
        fileManager: mockFileManager,
        httpClient: mockHTTPClient
    )

    let token: String? = await tokenManager.getToken()
    #expect(token == nil)
}

// MARK: - Mock Types

private final class MockHFFileManager: HFFileManagerProtocol, @unchecked Sendable {
    var mockFileContents: [String: String] = [:]
    var mockExpandedPaths: [String: String] = [:]

    deinit {
        // Cleanup mock resources if needed
    }

    func fileExists(atPath path: String) -> Bool {
        let expandedPath: String = mockExpandedPaths[path] ?? path
        return mockFileContents[expandedPath] != nil
    }

    func contents(atPath path: String) -> String? {
        let expandedPath: String = mockExpandedPaths[path] ?? path
        return mockFileContents[expandedPath]
    }

    func expandTildeInPath(_ path: String) -> String {
        mockExpandedPaths[path] ?? path
    }
}
