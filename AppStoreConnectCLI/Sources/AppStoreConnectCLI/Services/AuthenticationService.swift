import Foundation

/// Protocol defining authentication operations for App Store Connect API
public protocol AuthenticationService: Sendable {
    /// Authenticates with App Store Connect using the provided configuration
    /// - Parameter configuration: Configuration containing API credentials
    /// - Returns: Result containing success status or error
    /// - Throws: AppStoreConnectError for authentication failures
    func authenticate(with configuration: Configuration) async throws
    
    /// Validates that the current authentication is still valid
    /// - Returns: Result indicating authentication status
    /// - Throws: AppStoreConnectError if authentication is invalid
    func validateAuthentication() async throws -> Bool
    
    /// Gets the current authentication status
    /// - Returns: True if authenticated, false otherwise
    var isAuthenticated: Bool { get async }
    
    /// Refreshes the authentication token if needed
    /// - Throws: AppStoreConnectError for refresh failures
    func refreshAuthenticationIfNeeded() async throws
}

/// Result type for authentication operations
public typealias AuthenticationResult = Result<Void, AppStoreConnectError>

/// Authentication status information
public struct AuthenticationStatus: Sendable, Equatable {
    public let isValid: Bool
    public let expiresAt: Date?
    public let issuer: String?
    
    public init(isValid: Bool, expiresAt: Date? = nil, issuer: String? = nil) {
        self.isValid = isValid
        self.expiresAt = expiresAt
        self.issuer = issuer
    }
}
