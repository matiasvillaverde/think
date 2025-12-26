import Abstractions
import Foundation

extension RemoteProviderType {
    /// The keychain service identifier for this provider
    var keychainKey: String {
        "api_key_\(rawValue)"
    }
}

/// Protocol for managing API keys.
///
/// This protocol abstracts API key storage for testability.
public protocol APIKeyManaging: Sendable {
    /// Sets an API key for a provider.
    func setKey(_ key: String, for provider: RemoteProviderType) async throws

    /// Gets an API key for a provider.
    func getKey(for provider: RemoteProviderType) async throws -> String?

    /// Deletes an API key for a provider.
    func deleteKey(for provider: RemoteProviderType) async throws

    /// Checks if an API key exists for a provider.
    func hasKey(for provider: RemoteProviderType) async -> Bool
}

/// Manager for API keys stored in the keychain.
///
/// This actor provides a thread-safe interface for managing
/// API keys for various remote LLM providers.
public actor APIKeyManager: APIKeyManaging {
    /// The underlying secure storage
    private let storage: SecureStorageProtocol

    /// Shared instance with default keychain storage
    public static let shared = APIKeyManager(storage: KeychainStorage.shared)

    /// Creates a new API key manager.
    ///
    /// - Parameter storage: The secure storage backend to use
    public init(storage: SecureStorageProtocol) {
        self.storage = storage
    }

    public func setKey(_ key: String, for provider: RemoteProviderType) async throws {
        guard let data = key.data(using: .utf8) else {
            throw RemoteError.invalidAPIKey
        }
        try await storage.store(data, forKey: provider.keychainKey)
    }

    public func getKey(for provider: RemoteProviderType) async throws -> String? {
        guard let data = try await storage.retrieve(forKey: provider.keychainKey) else {
            return nil
        }
        guard let key = String(data: data, encoding: .utf8) else {
            throw KeychainError.invalidData
        }
        return key
    }

    public func deleteKey(for provider: RemoteProviderType) async throws {
        try await storage.delete(forKey: provider.keychainKey)
    }

    public func hasKey(for provider: RemoteProviderType) async -> Bool {
        await storage.exists(forKey: provider.keychainKey)
    }
}

/// Mock API key manager for testing.
public actor MockAPIKeyManager: APIKeyManaging {
    private var keys: [RemoteProviderType: String]

    public init(keys: [RemoteProviderType: String] = [:]) {
        self.keys = keys
    }

    public func setKey(_ key: String, for provider: RemoteProviderType) async throws {
        keys[provider] = key
    }

    public func getKey(for provider: RemoteProviderType) async throws -> String? {
        keys[provider]
    }

    public func deleteKey(for provider: RemoteProviderType) async throws {
        keys[provider] = nil
    }

    public func hasKey(for provider: RemoteProviderType) async -> Bool {
        keys[provider] != nil
    }
}
