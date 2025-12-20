import Foundation
import Security

/// Protocol for secure credential storage
public protocol SecureStorageService: Sendable {
    func store(key: String, value: String, service: String) async throws
    func retrieve(key: String, service: String) async throws -> String?
    func delete(key: String, service: String) async throws
    func exists(key: String, service: String) async -> Bool
}

/// Keychain-based implementation of SecureStorageService
public actor KeychainService: SecureStorageService {
    // MARK: - Properties
    private let accessGroup: String?
    
    // MARK: - Initialization
    public init(accessGroup: String? = nil) {
        self.accessGroup = accessGroup
    }
    
    // MARK: - SecureStorageService Implementation
    public func store(key: String, value: String, service: String) async throws {
        guard let data = value.data(using: .utf8) else {
            throw AppStoreConnectError.configurationError(
                message: "Failed to encode value as UTF-8"
            )
        }
        
        // Delete any existing item first
        try? await delete(key: key, service: service)
        
        var query = createBaseQuery(key: key, service: service)
        query[kSecValueData as String] = data
        
        let status = SecItemAdd(query as CFDictionary, nil)
        
        if status != errSecSuccess {
            throw AppStoreConnectError.configurationError(
                message: "Failed to store credential in Keychain: \(status)"
            )
        }
    }
    
    public func retrieve(key: String, service: String) async throws -> String? {
        var query = createBaseQuery(key: key, service: service)
        query[kSecReturnData as String] = kCFBooleanTrue
        query[kSecMatchLimit as String] = kSecMatchLimitOne
        
        var result: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &result)
        
        if status == errSecItemNotFound {
            return nil
        }
        
        if status != errSecSuccess {
            throw AppStoreConnectError.configurationError(
                message: "Failed to retrieve credential from Keychain: \(status)"
            )
        }
        
        guard let data = result as? Data,
              let value = String(data: data, encoding: .utf8) else {
            throw AppStoreConnectError.configurationError(
                message: "Failed to decode credential from Keychain"
            )
        }
        
        return value
    }
    
    public func delete(key: String, service: String) async throws {
        let query = createBaseQuery(key: key, service: service)
        let status = SecItemDelete(query as CFDictionary)
        
        if status != errSecSuccess && status != errSecItemNotFound {
            throw AppStoreConnectError.configurationError(
                message: "Failed to delete credential from Keychain: \(status)"
            )
        }
    }
    
    public func exists(key: String, service: String) async -> Bool {
        var query = createBaseQuery(key: key, service: service)
        query[kSecMatchLimit as String] = kSecMatchLimitOne
        
        let status = SecItemCopyMatching(query as CFDictionary, nil)
        return status == errSecSuccess
    }
    
    // MARK: - Private Helpers
    private func createBaseQuery(key: String, service: String) -> [String: Any] {
        var query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: key,
            kSecAttrSynchronizable as String: kCFBooleanFalse as Any
        ]
        
        if let accessGroup = accessGroup {
            query[kSecAttrAccessGroup as String] = accessGroup
        }
        
        return query
    }
}

// MARK: - Keychain Constants
public enum KeychainConstants {
    public static let serviceIdentifier = "com.think.appstoreconnect"
    public static let privateKeyIdentifier = "private-key"
    public static let keyIDIdentifier = "key-id"
    public static let issuerIDIdentifier = "issuer-id"
    public static let teamIDIdentifier = "team-id"
}

// MARK: - Secure Configuration Storage
public extension KeychainService {
    /// Stores App Store Connect configuration securely
    func storeConfiguration(_ config: Configuration) async throws {
        let service = KeychainConstants.serviceIdentifier
        
        // Store each component separately for flexibility
        try await store(
            key: KeychainConstants.keyIDIdentifier,
            value: config.keyID,
            service: service
        )
        
        try await store(
            key: KeychainConstants.issuerIDIdentifier,
            value: config.issuerID,
            service: service
        )
        
        if let teamID = config.teamID {
            try await store(
                key: KeychainConstants.teamIDIdentifier,
                value: teamID,
                service: service
            )
        }
        
        // Store private key content
        let privateKeyContent = try config.getPrivateKey()
        try await store(
            key: KeychainConstants.privateKeyIdentifier,
            value: privateKeyContent,
            service: service
        )
    }
    
    /// Retrieves App Store Connect configuration from secure storage
    func retrieveConfiguration(
        timeout: TimeInterval = 30.0,
        retryAttempts: Int = 3,
        verboseLogging: Bool = false
    ) async throws -> Configuration? {
        let service = KeychainConstants.serviceIdentifier
        
        guard let keyID = try await retrieve(
            key: KeychainConstants.keyIDIdentifier,
            service: service
        ) else { return nil }
        
        guard let issuerID = try await retrieve(
            key: KeychainConstants.issuerIDIdentifier,
            service: service
        ) else { return nil }
        
        guard let privateKeyContent = try await retrieve(
            key: KeychainConstants.privateKeyIdentifier,
            service: service
        ) else { return nil }
        
        let teamID = try await retrieve(
            key: KeychainConstants.teamIDIdentifier,
            service: service
        )
        
        return try Configuration(
            keyID: keyID,
            issuerID: issuerID,
            privateKeyContent: privateKeyContent,
            teamID: teamID,
            timeout: timeout,
            retryAttempts: retryAttempts,
            verboseLogging: verboseLogging
        )
    }
    
    /// Checks if configuration exists in secure storage
    func hasStoredConfiguration() async -> Bool {
        let service = KeychainConstants.serviceIdentifier
        
        let hasKeyID = await exists(
            key: KeychainConstants.keyIDIdentifier,
            service: service
        )
        
        let hasIssuerID = await exists(
            key: KeychainConstants.issuerIDIdentifier,
            service: service
        )
        
        let hasPrivateKey = await exists(
            key: KeychainConstants.privateKeyIdentifier,
            service: service
        )
        
        return hasKeyID && hasIssuerID && hasPrivateKey
    }
    
    /// Removes all stored configuration
    func clearConfiguration() async throws {
        let service = KeychainConstants.serviceIdentifier
        
        try await delete(
            key: KeychainConstants.keyIDIdentifier,
            service: service
        )
        
        try await delete(
            key: KeychainConstants.issuerIDIdentifier,
            service: service
        )
        
        try await delete(
            key: KeychainConstants.privateKeyIdentifier,
            service: service
        )
        
        try await delete(
            key: KeychainConstants.teamIDIdentifier,
            service: service
        )
    }
}
