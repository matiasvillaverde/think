import Testing
@testable import RemoteSession

@Suite("API Key Manager Tests")
struct APIKeyManagerTests {
    @Test("Set and get key for provider")
    func setAndGetKeyForProvider() async throws {
        let manager = MockAPIKeyManager()

        try await manager.setKey("sk-test-key", for: .openAI)
        let key = try await manager.getKey(for: .openAI)

        #expect(key == "sk-test-key")
    }

    @Test("Delete key for provider")
    func deleteKeyForProvider() async throws {
        let manager = MockAPIKeyManager(keys: [.openAI: "sk-test-key"])

        try await manager.deleteKey(for: .openAI)
        let key = try await manager.getKey(for: .openAI)

        #expect(key == nil)
    }

    @Test("Check key existence")
    func checkKeyExistence() async {
        let manager = MockAPIKeyManager(keys: [.openAI: "sk-test-key"])

        #expect(await manager.hasKey(for: .openAI))
        #expect(await !manager.hasKey(for: .anthropic))
    }

    @Test("Keys are isolated between providers")
    func keysAreIsolatedBetweenProviders() async throws {
        let manager = MockAPIKeyManager()

        try await manager.setKey("openai-key", for: .openAI)
        try await manager.setKey("anthropic-key", for: .anthropic)

        let openAIKey = try await manager.getKey(for: .openAI)
        let anthropicKey = try await manager.getKey(for: .anthropic)

        #expect(openAIKey == "openai-key")
        #expect(anthropicKey == "anthropic-key")
    }

    @Test("Get key returns nil for missing provider")
    func getKeyReturnsNilForMissingProvider() async throws {
        let manager = MockAPIKeyManager()

        let key = try await manager.getKey(for: .openAI)

        #expect(key == nil)
    }

    @Test("Has key returns false after delete")
    func hasKeyReturnsFalseAfterDelete() async throws {
        let manager = MockAPIKeyManager(keys: [.openAI: "sk-test-key"])

        #expect(await manager.hasKey(for: .openAI))

        try await manager.deleteKey(for: .openAI)

        #expect(await !manager.hasKey(for: .openAI))
    }
}
