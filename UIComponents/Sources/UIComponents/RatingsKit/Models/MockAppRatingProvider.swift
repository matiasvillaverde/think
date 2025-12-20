import Foundation

/// A mock implementation of the `AppRatingProviding` protocol for testing and preview purposes.
///
/// This provider returns predefined app rating data and can simulate network delays and errors.
public struct MockAppRatingProvider: AppRatingProviding {
    enum Constants {
        static let networkDelayNanoseconds: UInt64 = 3_000_000_000
        static let noReviewsAverageRating: Double = 4.8
        static let noReviewsTotalRatings: Int = 15
        static let withMockReviewsAverageRating: Double = 4.2
        static let withMockReviewsTotalRatings: Int = 1_250
        static let zeroRating: Double = 0.0
        static let zeroCount: Int = 0
    }

    /// The predefined response that will be returned by the `fetch` method.
    private let response: AppRatingResponse

    /// A flag indicating whether the `fetch` method should throw an error.
    private let shouldThrowError: Bool

    /// Errors that can be thrown by the mock provider.
    enum MockError: LocalizedError {
        /// A generic error used for testing error handling.
        case genericError

        /// A localized description of the error.
        var errorDescription: String? {
            "A generic error occurred while fetching the app rating."
        }
    }

    /// Creates a new mock app rating provider with specified behavior.
    ///
    /// - Parameters:
    ///   - response: The predefined response that will be returned by the `fetch` method.
    ///   - shouldThrowError: A flag indicating whether the `fetch` method should throw an error.
    public init(
        response: AppRatingResponse,
        shouldThrowError: Bool = false
    ) {
        self.response = response
        self.shouldThrowError = shouldThrowError
    }

    /// Fetches the mock app rating data with a simulated delay.
    ///
    /// - Returns: The predefined `AppRatingResponse`.
    /// - Throws: `MockError.genericError` if `shouldThrowError` is `true`.
    public func fetch() async throws -> AppRatingResponse {
        // Simulating network delay
        try? await Task.sleep(nanoseconds: Constants.networkDelayNanoseconds)

        if shouldThrowError {
            throw MockError.genericError
        }

        return response
    }
}
