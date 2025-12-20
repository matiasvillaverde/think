import Foundation
@preconcurrency import AppStoreConnect_Swift_SDK

/// Service for fetching customer reviews from App Store Connect
public actor ReviewsService {
    private let apiClient: any AppStoreConnectAPIClientProtocol
    
    public init(apiClient: any AppStoreConnectAPIClientProtocol) {
        self.apiClient = apiClient
    }
    
    /// Convenience initializer that creates a live API client
    public init(authService: AppStoreConnectAuthenticationService) {
        self.apiClient = LiveAppStoreConnectAPIClient(authService: authService)
    }
    
    /// Fetches all customer reviews for a given app
    /// - Parameter appId: The App Store Connect app ID
    /// - Returns: Array of customer reviews
    /// - Throws: AppStoreConnectError for API failures
    public func fetchAllReviews(appId: String) async throws -> [CustomerReview] {
        return try await apiClient.fetchAllCustomerReviews(appId: appId)
    }
}
