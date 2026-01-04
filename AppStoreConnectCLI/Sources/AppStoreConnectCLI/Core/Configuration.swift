import Foundation

/// Configuration management for App Store Connect CLI
public struct Configuration: Sendable {
    // MARK: - Properties
    public let keyID: String
    public let issuerID: String
    public let privateKeyPath: String?
    public let privateKeyContent: String?
    public let teamID: String?
    public let timeout: TimeInterval
    public let retryAttempts: Int
    public let verboseLogging: Bool
    
    // MARK: - Default Values
    private static let defaultTimeout: TimeInterval = 120.0 // Increased for App Store Connect API
    private static let defaultRetryAttempts: Int = 3
    
    // MARK: - Initialization
    public init(
        keyID: String,
        issuerID: String,
        privateKeyPath: String? = nil,
        privateKeyContent: String? = nil,
        teamID: String? = nil,
        timeout: TimeInterval = 120.0,
        retryAttempts: Int = 3,
        verboseLogging: Bool = false
    ) throws {
        self.keyID = keyID
        self.issuerID = issuerID
        self.privateKeyPath = privateKeyPath
        self.privateKeyContent = privateKeyContent
        self.teamID = teamID
        self.timeout = timeout
        self.retryAttempts = retryAttempts
        self.verboseLogging = verboseLogging
        
        // Validate that we have either a key path or key content
        if privateKeyPath == nil && privateKeyContent == nil {
            throw AppStoreConnectError.configurationError(
                message: "Either privateKeyPath or privateKeyContent must be provided"
            )
        }
    }
    
    // MARK: - Secure Loading Methods
    /// Loads configuration with priority: Keychain > Environment > File
    /// This is the recommended method for production use
    public static func loadSecure(
        keychainService: SecureStorageService? = nil,
        configFilePath: String? = nil
    ) async throws -> Configuration {
        let keychain = keychainService ?? KeychainService()
        
        // First, try to load from Keychain (most secure)
        if let keychainConfig = try await (keychain as? KeychainService)?.retrieveConfiguration() {
            return keychainConfig
        }
        
        // Second, try environment variables (for CI/CD)
        if let envConfig = try? fromEnvironment() {
            // Warn about security implications
            if envConfig.privateKeyContent != nil {
                // In production, we should use a proper logger
                // For now, we'll note this as a security concern
            }
            return envConfig
        }
        
        // Third, try config file if provided
        if let filePath = configFilePath {
            return try fromFile(at: filePath)
        }
        
        // If all methods fail, provide helpful error
        throw AppStoreConnectError.configurationError(
            message: "No configuration found. Please run 'app-store-cli auth setup' to configure" +
                    " credentials securely."
        )
    }
    
    // MARK: - Environment Loading
    /// Creates configuration from environment variables
    /// WARNING: This method is less secure than Keychain storage
    /// Only use for CI/CD environments where Keychain access is not available
    public static func fromEnvironment() throws -> Configuration {
        // Required environment variables
        guard let keyID = ProcessInfo.processInfo.environment["APPSTORE_KEY_ID"] ??
                         ProcessInfo.processInfo.environment["APP_STORE_CONNECT_API_KEY_ID"] 
        else {
            throw AppStoreConnectError.missingEnvironmentVariable(name: "APPSTORE_KEY_ID")
        }
        
        let shortIssuerID = ProcessInfo.processInfo.environment["APPSTORE_ISSUER_ID"]
        let altIssuerID = ProcessInfo.processInfo.environment["APP_STORE_CONNECT_API_KEY_ISSUER_ID"]
        guard let issuerID = shortIssuerID ?? altIssuerID
        else {
            throw AppStoreConnectError.missingEnvironmentVariable(name: "APPSTORE_ISSUER_ID")
        }
        
        // Optional environment variables
        let privateKeyPath = ProcessInfo.processInfo.environment["APP_STORE_CONNECT_API_KEY_PATH"]
                           ?? ProcessInfo.processInfo.environment["APPSTORE_KEY_PATH"]
        let privateKeyContent = ProcessInfo.processInfo.environment["APPSTORE_P8_KEY"]
        let teamID = ProcessInfo.processInfo.environment["TEAM_ID"] ??
                    ProcessInfo.processInfo.environment["DEVELOPMENT_TEAM"]
        
        // Parse optional numeric values
        let timeout = parseTimeInterval(
            from: ProcessInfo.processInfo.environment["APPSTORE_TIMEOUT"]
        ) ?? defaultTimeout
        let retryAttempts = parseInt(
            from: ProcessInfo.processInfo.environment["APPSTORE_RETRY_ATTEMPTS"]
        ) ?? defaultRetryAttempts
        let verboseLogging = parseBool(
            from: ProcessInfo.processInfo.environment["APPSTORE_VERBOSE"]
        ) ?? false
        
        return try Configuration(
            keyID: keyID,
            issuerID: issuerID,
            privateKeyPath: privateKeyPath,
            privateKeyContent: privateKeyContent,
            teamID: teamID,
            timeout: timeout,
            retryAttempts: retryAttempts,
            verboseLogging: verboseLogging
        )
    }
    
    // MARK: - File Loading
    /// Creates configuration from a JSON file
    public static func fromFile(at path: String) throws -> Configuration {
        guard FileManager.default.fileExists(atPath: path) else {
            throw AppStoreConnectError.fileNotFound(path: path)
        }
        
        do {
            let data = try Data(contentsOf: URL(fileURLWithPath: path))
            let decoder = JSONDecoder()
            decoder.keyDecodingStrategy = .convertFromSnakeCase
            return try decoder.decode(Configuration.self, from: data)
        } catch {
            throw AppStoreConnectError.fileReadError(
                path: path,
                reason: "Failed to decode configuration: \(error.localizedDescription)"
            )
        }
    }
    
    // MARK: - Private Key Access
    /// Returns the private key content, loading from file if necessary
    public func getPrivateKey() throws -> String {
        if let privateKeyContent = privateKeyContent {
            return privateKeyContent
        }
        
        guard let privateKeyPath = privateKeyPath else {
            throw AppStoreConnectError.configurationError(
                message: "No private key path or content available"
            )
        }
        
        guard FileManager.default.fileExists(atPath: privateKeyPath) else {
            throw AppStoreConnectError.fileNotFound(path: privateKeyPath)
        }
        
        do {
            return try String(contentsOfFile: privateKeyPath, encoding: .utf8)
        } catch {
            throw AppStoreConnectError.fileReadError(
                path: privateKeyPath,
                reason: error.localizedDescription
            )
        }
    }
    
    // MARK: - Validation
    /// Validates the configuration
    public func validate() throws {
        // Validate key ID format (should be 10 characters)
        if keyID.count != 10 {
            throw AppStoreConnectError.invalidConfiguration(
                field: "keyID",
                value: "Should be 10 characters, got \(keyID.count)"
            )
        }
        
        // Validate issuer ID format (should be UUID format)
        let uuidPattern = "^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}" +
                         "-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}$"
        if issuerID.range(of: uuidPattern, options: .regularExpression) == nil {
            throw AppStoreConnectError.invalidConfiguration(
                field: "issuerID",
                value: "Should be in UUID format"
            )
        }
        
        // Validate timeout
        if timeout <= 0 {
            throw AppStoreConnectError.invalidConfiguration(
                field: "timeout",
                value: "Should be greater than 0"
            )
        }
        
        // Validate retry attempts
        if retryAttempts < 0 {
            throw AppStoreConnectError.invalidConfiguration(
                field: "retryAttempts",
                value: "Should be 0 or greater"
            )
        }
        
        // Validate private key if provided
        if let privateKeyContent = privateKeyContent {
            try validatePrivateKey(privateKeyContent)
        } else if privateKeyPath != nil {
            let content = try getPrivateKey()
            try validatePrivateKey(content)
        }
    }
    
    // MARK: - Private Helpers
    private static func parseTimeInterval(from string: String?) -> TimeInterval? {
        guard let string = string, let value = Double(string) else { return nil }
        return value
    }
    
    private static func parseInt(from string: String?) -> Int? {
        guard let string = string, let value = Int(string) else { return nil }
        return value
    }
    
    private static func parseBool(from string: String?) -> Bool? {
        guard let string = string else { return nil }
        return ["true", "1", "yes", "on"].contains(string.lowercased())
    }
    
    private func validatePrivateKey(_ content: String) throws {
        let trimmedContent = content.trimmingCharacters(in: .whitespacesAndNewlines)
        let pemBegin = "-----BEGIN " + "PRIVATE KEY-----"
        let pemEnd = "-----END " + "PRIVATE KEY-----"
        
        // Check for PEM format
        if !trimmedContent.hasPrefix(pemBegin) || !trimmedContent.hasSuffix(pemEnd) {
            throw AppStoreConnectError.invalidAPIKey(
                reason: "Private key must be in PEM format"
            )
        }
        
        // Check minimum length (a valid P-256 key should have sufficient content)
        if trimmedContent.count < 200 {
            throw AppStoreConnectError.invalidAPIKey(
                reason: "Private key appears to be too short"
            )
        }
    }
}

// MARK: - Codable Implementation
extension Configuration: Codable {
    enum CodingKeys: String, CodingKey {
        case keyID = "key_id"
        case issuerID = "issuer_id"
        case privateKeyPath = "private_key_path"
        case privateKeyContent = "private_key_content"
        case teamID = "team_id"
        case timeout
        case retryAttempts = "retry_attempts"
        case verboseLogging = "verbose_logging"
    }
}

// MARK: - Test Support
public protocol ConfigurationProvider {
    func getConfiguration() async throws -> Configuration
}

// MARK: - Mock Configuration Provider for Testing
public struct MockConfigurationProvider: ConfigurationProvider {
    private let configuration: Configuration
    
    public init(configuration: Configuration) {
        self.configuration = configuration
    }
    
    public func getConfiguration() async throws -> Configuration {
        return configuration
    }
    
    /// Creates a mock provider with test configuration
    /// Private keys are generated dynamically for each test
    public static func createTestProvider() throws -> MockConfigurationProvider {
        // Generate a valid but fake PEM key for testing
        let testKey = generateTestPrivateKey()
        
        let config = try Configuration(
            keyID: "TEST\(UUID().uuidString.prefix(6))",
            issuerID: UUID().uuidString,
            privateKeyContent: testKey,
            timeout: 10.0,
            retryAttempts: 1,
            verboseLogging: true
        )
        
        return MockConfigurationProvider(configuration: config)
    }
    
    private static func generateTestPrivateKey() -> String {
        // This generates a structurally valid but cryptographically useless key
        // Only for testing purposes - not a real private key
        let randomBytes = (0..<64).map { _ in 
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
