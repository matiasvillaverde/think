import Foundation
@preconcurrency import AppStoreConnect_Swift_SDK

/// Live implementation of AppStoreConnectAPIClientProtocol using the AppStoreConnect SDK
public struct LiveAppStoreConnectAPIClient: AppStoreConnectAPIClientProtocol {
    private let authService: AppStoreConnectAuthenticationService
    
    public init(authService: AppStoreConnectAuthenticationService) {
        self.authService = authService
    }
    
    public func fetchAllCustomerReviews(appId: String) async throws -> [CustomerReview] {
        let provider = try await authService.getAPIProvider()
        
        // Create the customer reviews request for the specific app
        let request = APIEndpoint.v1.apps.id(appId).customerReviews.get()
        
        // Use the SDK's paged method to handle pagination automatically
        var allReviews: [CustomerReview] = []
        
        for try await response in provider.paged(request) {
            allReviews.append(contentsOf: response.data)
        }
        
        return allReviews
    }
}
