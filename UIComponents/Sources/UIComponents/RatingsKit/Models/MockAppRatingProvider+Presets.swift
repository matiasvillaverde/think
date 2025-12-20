import Foundation

extension MockAppRatingProvider {
    /// A provider that returns an app with ratings but no reviews.
    static let noReviews: MockAppRatingProvider = .init(response: .init(
        averageRating: Constants.noReviewsAverageRating,
        totalRatings: Constants.noReviewsTotalRatings,
        reviews: []
    ))

    /// A provider that returns an app with no ratings and no reviews.
    static let noRatingsOrReviews: MockAppRatingProvider = .init(
        response: .init(
            averageRating: Constants.zeroRating,
            totalRatings: Constants.zeroCount,
            reviews: []
        )
    )

    /// A provider that returns an app with ratings and a collection of mock reviews.
    static let withMockReviews: MockAppRatingProvider = .init(
        response: .init(
            averageRating: Constants.withMockReviewsAverageRating,
            totalRatings: Constants.withMockReviewsTotalRatings,
            reviews: .mock()
        )
    )

    /// A provider that simulates a network error when trying to fetch ratings.
    static let throwsError: MockAppRatingProvider = .init(
        response: .init(
            averageRating: Constants.zeroRating,
            totalRatings: Constants.zeroCount,
            reviews: []
        ),
        shouldThrowError: true
    )
}
