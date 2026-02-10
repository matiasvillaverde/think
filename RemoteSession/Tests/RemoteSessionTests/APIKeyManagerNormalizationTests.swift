import Foundation
import Testing
@testable import RemoteSession

@Suite("APIKeyManager Normalization Tests")
struct APIKeyManagerNormalizationTests {
    private final actor InMemoryStorage: SecureStorageProtocol {
        private var store: [String: Data] = [:]

        func store(_ data: Data, forKey key: String) async throws {
            store[key] = data
        }

        func retrieve(forKey key: String) async throws -> Data? {
            store[key]
        }

        func delete(forKey key: String) async throws {
            store[key] = nil
        }

        func exists(forKey key: String) async -> Bool {
            store[key] != nil
        }
    }

    @Test("Trims whitespace/newlines on set/get")
    func trimsKeyOnRoundTrip() async throws {
        let storage = InMemoryStorage()
        let manager = APIKeyManager(storage: storage)

        try await manager.setKey("  sk-test-key\n", for: .openRouter)
        let fetched = try await manager.getKey(for: .openRouter)

        #expect(fetched == "sk-test-key")
    }
}
