import Foundation
import Testing
@testable import AppStoreConnectCLI
@preconcurrency import AppStoreConnect_Swift_SDK

@Suite("ReviewsService Tests")
struct ReviewsServiceTests {
    
    @Test("ReviewsService can be initialized")
    func testReviewsServiceInitialization() async throws {
        // Given: A mock API client
        let mockClient = MockAPIClient()
        
        // When: Creating a ReviewsService
        let service = ReviewsService(apiClient: mockClient)
        
        // Then: Service is created successfully (compilation confirms this)
        _ = service // Suppress unused variable warning
    }
    
    @Test("ReviewsService can fetch all customer reviews")
    func testFetchAllCustomerReviews() async throws {
        // Given: A mock API client with sample reviews
        let mockClient = MockAPIClient()
        let service = ReviewsService(apiClient: mockClient)
        let appId = "123456789"
        
        // When: Fetching all customer reviews
        let reviews = try await service.fetchAllReviews(appId: appId)
        
        // Then: Should return the expected reviews
        #expect(reviews.count == 2)
        #expect(reviews[0].id == "review1")
        #expect(reviews[1].id == "review2")
    }
}

// MARK: - Mock API Client
private final class MockAPIClient: AppStoreConnectAPIClientProtocol {
    func fetchAllCustomerReviews(appId: String) async throws -> [CustomerReview] {
        // Return sample customer reviews for testing
        return [
            CustomerReview(
                type: .customerReviews,
                id: "review1",
                attributes: CustomerReview.Attributes(
                    rating: 5,
                    title: "Great app!",
                    body: "Love this app, works perfectly.",
                    reviewerNickname: "HappyUser",
                    createdDate: Date(),
                    territory: .usa
                ),
                relationships: nil,
                links: nil
            ),
            CustomerReview(
                type: .customerReviews,
                id: "review2",
                attributes: CustomerReview.Attributes(
                    rating: 4,
                    title: "Good but could be better",
                    body: "Nice app but missing some features.",
                    reviewerNickname: "CriticalUser", 
                    createdDate: Date(),
                    territory: .usa
                ),
                relationships: nil,
                links: nil
            )
        ]
    }
}
