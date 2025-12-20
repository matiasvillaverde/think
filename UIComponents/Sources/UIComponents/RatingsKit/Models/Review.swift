import Foundation

/// A model representing a user review with rating and metadata.
///
/// This struct encapsulates all information related to a single review, including
/// the review title, content, rating score, author information, and date.
public struct Review: Decodable, Sendable, Hashable {
    /// The title or headline of the review.
    public let title: String

    /// The main content or body text of the review.
    public let content: String

    /// The numerical rating given by the reviewer (typically on a scale of 1-5).
    public let rating: Int

    /// The name of the person who wrote the review.
    public let author: String

    /// The date when the review was submitted.
    public let date: Date

    /// Creates a new review with the specified details.
    ///
    /// - Parameters:
    ///   - title: The title or headline of the review.
    ///   - content: The main content or body text of the review.
    ///   - rating: The numerical rating given by the reviewer (typically 1-5).
    ///   - author: The name of the person who wrote the review.
    ///   - date: The date when the review was submitted.
    public init(
        title: String,
        content: String,
        rating: Int,
        author: String,
        date: Date
    ) {
        self.title = title
        self.content = content
        self.rating = rating
        self.author = author
        self.date = date
    }
}

private enum TimeIntervals {
    static let secondsInDay: TimeInterval = 86_400
    static let secondsInTwoDays: TimeInterval = 172_800
    static let secondsInThreeMonths: TimeInterval = 7_776_000
    static let secondsInSixMonths: TimeInterval = 15_552_000
    static let secondsInYear: TimeInterval = 31_536_000
}

private enum Defaults {
    static let defaultRating: Int = 4
    static let excellentRating: Int = 5
    static let goodRating: Int = 4
    static let averageRating: Int = 3
    static let poorRating: Int = 2
}
