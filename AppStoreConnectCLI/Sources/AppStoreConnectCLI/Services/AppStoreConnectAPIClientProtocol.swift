import Foundation
@preconcurrency import AppStoreConnect_Swift_SDK

/// Protocol for accessing App Store Connect API with pagination support
public protocol AppStoreConnectAPIClientProtocol: Sendable {
    /// Returns customer reviews for an app with automatic pagination
    /// - Parameter appId: The app ID to fetch reviews for
    /// - Returns: Array of all customer reviews
    /// - Throws: AppStoreConnectError for API failures
    func fetchAllCustomerReviews(appId: String) async throws -> [CustomerReview]
}
