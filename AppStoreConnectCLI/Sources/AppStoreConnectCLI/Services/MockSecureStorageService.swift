import Foundation

/// Mock implementation of SecureStorageService for testing
public actor MockSecureStorageService: SecureStorageService {
    private var storage: [String: [String: String]] = [:]
    
    public init() {}
    
    public func store(key: String, value: String, service: String) async throws {
        if storage[service] == nil {
            storage[service] = [:]
        }
        storage[service]?[key] = value
    }
    
    public func retrieve(key: String, service: String) async throws -> String? {
        return storage[service]?[key]
    }
    
    public func delete(key: String, service: String) async throws {
        storage[service]?[key] = nil
    }
    
    public func exists(key: String, service: String) async -> Bool {
        return storage[service]?[key] != nil
    }
    
    /// Helper method to clear all stored data
    public func clearAll() async {
        storage.removeAll()
    }
    
    /// Helper method to get all stored data for testing
    public func getAllData() async -> [String: [String: String]] {
        return storage
    }
}

// MARK: - Test Helpers
extension MockSecureStorageService {
    /// Pre-populate with test configuration
    public func populateTestConfiguration() async throws {
        let service = KeychainConstants.serviceIdentifier
        
        try await store(
            key: KeychainConstants.keyIDIdentifier,
            value: "TEST123456",
            service: service
        )
        
        try await store(
            key: KeychainConstants.issuerIDIdentifier,
            value: UUID().uuidString,
            service: service
        )
        
        try await store(
            key: KeychainConstants.privateKeyIdentifier,
            value: MockConfigurationProvider.generateTestPrivateKey(),
            service: service
        )
        
        try await store(
            key: KeychainConstants.teamIDIdentifier,
            value: "TESTTEAM123",
            service: service
        )
    }
}

// MARK: - Private Extension for Test Key Generation
private extension MockConfigurationProvider {
    static func generateTestPrivateKey() -> String {
        let randomBytes = (0..<32).map { _ in
            String(format: "%02x", Int.random(in: 0...255))
        }.joined()
        
        let pemBegin = "-----BEGIN " + "PRIVATE KEY-----"
        let pemEnd = "-----END " + "PRIVATE KEY-----"
        return """
        \(pemBegin)
        MIGHAgEAMBMGByqGSM49AgEGCCqGSM49AwEHBG0wawIBAQQg\(randomBytes)
        hRANCAASCGCCqGSM49AwEHBG0wawIBAQQghRANCAASCGCCqG
        SM49AwEHBG0wawIBAQQghRANCAASCGCCqGSM49AwEHBG0waw
        \(pemEnd)
        """
    }
}
