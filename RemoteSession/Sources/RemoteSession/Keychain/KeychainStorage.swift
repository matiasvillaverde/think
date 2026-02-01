import Foundation
import Security

/// Protocol for secure storage operations.
///
/// This protocol abstracts keychain access for testability.
public protocol SecureStorageProtocol: Sendable {
    /// Stores data securely.
    func store(_ data: Data, forKey key: String) async throws

    /// Retrieves data for a key.
    func retrieve(forKey key: String) async throws -> Data?

    /// Deletes data for a key.
    func delete(forKey key: String) async throws

    /// Checks if a key exists.
    func exists(forKey key: String) async -> Bool
}

/// Keychain-based secure storage implementation.
///
/// Uses the macOS/iOS Keychain Services to securely store sensitive data
/// like API keys. Data is encrypted at rest by the operating system.
public final class KeychainStorage: SecureStorageProtocol, @unchecked Sendable {
    /// The service identifier for keychain items
    private let service: String
    private let legacyService: String?

    /// Shared instance with default service name
    public static let shared = KeychainStorage(service: "com.think.remotesession")

    /// Creates a new keychain storage.
    ///
    /// - Parameter service: The keychain service identifier
    public init(service: String, legacyService: String? = "com.thinkfreely.remotesession") {
        self.service = service
        self.legacyService = legacyService
    }

    public func store(_ data: Data, forKey key: String) async throws {
        // Try to update first
        let updateQuery: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: key
        ]

        let updateAttributes: [String: Any] = [
            kSecValueData as String: data
        ]

        var status = SecItemUpdate(
            updateQuery as CFDictionary,
            updateAttributes as CFDictionary
        )

        // If item doesn't exist, add it
        if status == errSecItemNotFound {
            let addQuery: [String: Any] = [
                kSecClass as String: kSecClassGenericPassword,
                kSecAttrService as String: service,
                kSecAttrAccount as String: key,
                kSecValueData as String: data,
                kSecAttrAccessible as String: kSecAttrAccessibleAfterFirstUnlock
            ]

            status = SecItemAdd(addQuery as CFDictionary, nil)
        }

        guard status == errSecSuccess else {
            throw KeychainError.storeFailed(status)
        }
    }

    public func retrieve(forKey key: String) async throws -> Data? {
        if let data = try retrieve(forKey: key, service: service) {
            return data
        }

        guard let legacyService else {
            return nil
        }

        if let legacyData = try retrieve(forKey: key, service: legacyService) {
            try await store(legacyData, forKey: key)
            try delete(forKey: key, service: legacyService)
            return legacyData
        }

        return nil
    }

    private func retrieve(forKey key: String, service: String) throws -> Data? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: key,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne
        ]

        var result: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &result)

        switch status {
        case errSecSuccess:
            return result as? Data
        case errSecItemNotFound:
            return nil
        default:
            throw KeychainError.retrieveFailed(status)
        }
    }

    public func delete(forKey key: String) async throws {
        try delete(forKey: key, service: service)
        if let legacyService {
            try delete(forKey: key, service: legacyService)
        }
    }

    private func delete(forKey key: String, service: String) throws {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: key
        ]

        let status = SecItemDelete(query as CFDictionary)

        // It's okay if the item doesn't exist
        guard status == errSecSuccess || status == errSecItemNotFound else {
            throw KeychainError.deleteFailed(status)
        }
    }

    public func exists(forKey key: String) async -> Bool {
        if exists(forKey: key, service: service) {
            return true
        }
        guard let legacyService else {
            return false
        }
        return exists(forKey: key, service: legacyService)
    }

    private func exists(forKey key: String, service: String) -> Bool {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: key,
            kSecReturnData as String: false
        ]

        let status = SecItemCopyMatching(query as CFDictionary, nil)
        return status == errSecSuccess
    }
}

/// Keychain-specific errors.
enum KeychainError: Error, Sendable {
    case storeFailed(OSStatus)
    case retrieveFailed(OSStatus)
    case deleteFailed(OSStatus)
    case invalidData
}
