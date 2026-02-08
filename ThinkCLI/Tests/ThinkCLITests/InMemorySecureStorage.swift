import Foundation
import RemoteSession

actor InMemorySecureStorage: SecureStorageProtocol {
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
