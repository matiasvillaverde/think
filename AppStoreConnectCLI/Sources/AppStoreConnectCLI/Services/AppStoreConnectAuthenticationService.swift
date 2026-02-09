import Foundation
@preconcurrency import AppStoreConnect_Swift_SDK

/// Concrete implementation of AuthenticationService using AppStoreConnect-Swift-SDK
public actor AppStoreConnectAuthenticationService: AuthenticationService {
    // MARK: - Properties
    private var apiProvider: APIProvider?
    private var currentConfiguration: Configuration?
    private var authenticationDate: Date?
    private let tokenValidityDuration: TimeInterval = 1200 // 20 minutes
    
    // MARK: - Initialization
    public init() {}
    
    // MARK: - AuthenticationService Protocol
    public func authenticate(with configuration: Configuration) async throws {
        do {
            // Validate configuration first
            try configuration.validate()
            
            // Get the private key content
            let privateKeyContent = try configuration.getPrivateKey()
            
            // Extract the base64 content from PEM format
            let base64PrivateKey = try extractBase64FromPEM(privateKeyContent)
            
            // Create API configuration using AppStoreConnect SDK
            let apiConfiguration = try APIConfiguration(
                issuerID: configuration.issuerID,
                privateKeyID: configuration.keyID,
                privateKey: base64PrivateKey
            )
            
            // Create API provider
            self.apiProvider = APIProvider(configuration: apiConfiguration)
            
            // Test the authentication by making a simple API call
            try await validateConnection()
            
            // Store successful authentication details
            self.currentConfiguration = configuration
            self.authenticationDate = Date()
            
            if configuration.verboseLogging {
                CLIOutput.success("Successfully authenticated with App Store Connect API")
                CLIOutput.keyValue("Issuer ID", configuration.issuerID)
                CLIOutput.keyValue("Key ID", configuration.keyID)
            }
            
        } catch let error as AppStoreConnectError {
            throw error
        } catch {
            throw AppStoreConnectError.authenticationFailed(
                reason: "Failed to create API configuration: \(error.localizedDescription)"
            )
        }
    }
    
    public func validateAuthentication() async throws -> Bool {
        guard apiProvider != nil else {
            return false
        }
        
        // Check if token is still valid based on time
        if let authDate = authenticationDate {
            let timeElapsed = Date().timeIntervalSince(authDate)
            if timeElapsed >= tokenValidityDuration {
                return false
            }
        }
        
        // Test with a lightweight API call
        do {
            try await validateConnection()
            return true
        } catch {
            return false
        }
    }
    
    public var isAuthenticated: Bool {
        get async {
            do {
                return try await validateAuthentication()
            } catch {
                return false
            }
        }
    }
    
    public func refreshAuthenticationIfNeeded() async throws {
        guard let configuration = currentConfiguration else {
            throw AppStoreConnectError.authenticationFailed(
                reason: "No configuration available for refresh"
            )
        }
        
        let isValid = try await validateAuthentication()
        if !isValid {
            try await authenticate(with: configuration)
        }
    }
    
    // MARK: - Public API Provider Access
    /// Gets the current API provider for use by other services
    /// - Returns: The authenticated API provider
    /// - Throws: AppStoreConnectError if not authenticated
    public func getAPIProvider() async throws -> APIProvider {
        guard let provider = apiProvider else {
            throw AppStoreConnectError.authenticationFailed(
                reason: "Not authenticated. Call authenticate() first."
            )
        }
        return provider
    }
    
    // MARK: - Private Helpers
    private func extractBase64FromPEM(_ pemContent: String) throws -> String {
        let lines = pemContent.components(separatedBy: .newlines)
        var base64Content = ""
        var isInKey = false
        
        for line in lines {
            if line.contains("BEGIN PRIVATE KEY") {
                isInKey = true
                continue
            }
            if line.contains("END PRIVATE KEY") {
                break
            }
            if isInKey && !line.isEmpty {
                base64Content += line
            }
        }
        
        guard !base64Content.isEmpty else {
            throw AppStoreConnectError.invalidAPIKey(
                reason: "Failed to extract base64 content from PEM format"
            )
        }
        
        return base64Content
    }
    
    private func validateConnection() async throws {
        guard let provider = apiProvider else {
            throw AppStoreConnectError.authenticationFailed(
                reason: "API provider not initialized"
            )
        }
        
        do {
            // Make a simple API call to validate the connection
            // Using the users endpoint as it's lightweight and always available
            let request = APIEndpoint.v1.users.get()
            _ = try await provider.request(request)
            
        } catch {
            // Handle specific API errors
            if let apiError = error as? APIProvider.Error {
                switch apiError {
                case .requestFailure(let statusCode, let errorResponse, _):
                    if statusCode == 401 {
                        throw AppStoreConnectError.authenticationFailed(
                            reason: "Invalid credentials (401 Unauthorized)"
                        )
                    } else if statusCode == 403 {
                        throw AppStoreConnectError.authenticationFailed(
                            reason: "Insufficient permissions (403 Forbidden)"
                        )
                    } else {
                        let message = errorResponse?.errors?.first?.detail ?? "Unknown API error"
                        throw AppStoreConnectError.apiRequestFailed(
                            statusCode: statusCode,
                            message: message
                        )
                    }
                // Note: NetworkError case removed as it may not exist in this SDK version
                default:
                    throw AppStoreConnectError.authenticationFailed(
                        reason: "Authentication validation failed: \(error.localizedDescription)"
                    )
                }
            } else {
                throw AppStoreConnectError.authenticationFailed(
                    reason: "Authentication validation failed: \(error.localizedDescription)"
                )
            }
        }
    }
}

// MARK: - Factory Methods
extension AppStoreConnectAuthenticationService {
    /// Creates and authenticates a service instance from environment variables
    /// - Returns: Authenticated service instance
    /// - Throws: AppStoreConnectError for configuration or authentication failures
    public static func fromEnvironment() async throws -> AppStoreConnectAuthenticationService {
        let configuration = try Configuration.fromEnvironment()
        let service = AppStoreConnectAuthenticationService()
        try await service.authenticate(with: configuration)
        return service
    }
    
    /// Creates and authenticates a service instance from a configuration file
    /// - Parameter path: Path to the configuration file
    /// - Returns: Authenticated service instance
    /// - Throws: AppStoreConnectError for file, configuration, or authentication failures
    public static func fromFile(
        at path: String
    ) async throws -> AppStoreConnectAuthenticationService {
        let configuration = try Configuration.fromFile(at: path)
        let service = AppStoreConnectAuthenticationService()
        try await service.authenticate(with: configuration)
        return service
    }
}
