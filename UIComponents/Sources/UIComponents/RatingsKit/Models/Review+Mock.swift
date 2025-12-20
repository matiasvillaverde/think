import Foundation

// Import the constants from Review.swift
private enum Defaults {
    static let defaultRating: Int = 4
    static let excellentRating: Int = 5
    static let goodRating: Int = 4
    static let averageRating: Int = 3
    static let poorRating: Int = 2
}

private enum TimeIntervals {
    static let secondsInDay: TimeInterval = 86_400
    static let secondsInTwoDays: TimeInterval = 172_800
    static let secondsInThreeMonths: TimeInterval = 7_776_000
    static let secondsInSixMonths: TimeInterval = 15_552_000
    static let secondsInYear: TimeInterval = 31_536_000
}

extension Review {
    /// Creates a mock review for testing and preview purposes.
    ///
    /// - Parameter rating: The rating value to assign to the mock review (defaults to 4).
    /// - Returns: A fully populated mock `Review` instance.
    static func mock(rating: Int = Defaults.defaultRating) -> Review {
        Review(
            title: "Absolutely Love This App!",
            content: """
            This is an incredible app that has completely transformed how I work. \
            The interface is intuitive, and the features are exactly what I needed. \
            Highly recommend to everyone!
            """,
            rating: rating,
            author: "John Appleseed",
            date: Date()
        )
    }
}

extension [Review] {
    /// Creates an array of mock reviews with different ratings and dates for testing and
    /// preview purposes.
    ///
    /// - Returns: An array containing 6 different mock review instances with varying content.
    static func mock() -> Self {
        [
            .mock(rating: Defaults.excellentRating),
            Review(
                title: "Great Potential",
                content: """
                Very promising app with some really useful features. \
                Looking forward to future updates!
                """,
                rating: Defaults.goodRating,
                author: "Sarah Wilson",
                date: Date().addingTimeInterval(-TimeIntervals.secondsInDay) // Yesterday
            ),
            Review(
                title: "Needs Improvement",
                content: "Good concept but needs some work on performance.",
                rating: Defaults.averageRating,
                author: "Mike Thompson",
                date: Date().addingTimeInterval(-TimeIntervals.secondsInTwoDays) // 2 days ago
            ),
            Review(
                title: "Life Changing App",
                content: """
                I've been using this app for months now and it has completely \
                changed how I organize my work. The recent updates make it even better!
                """,
                rating: Defaults.excellentRating,
                author: "Emily Chen",
                date: Date().addingTimeInterval(-TimeIntervals.secondsInThreeMonths) // 3 months ago
            ),
            Review(
                title: "Could Be Better",
                content: "The app is okay but crashes sometimes. Hope this gets fixed soon.",
                rating: Defaults.poorRating,
                author: "David Brown",
                date: Date().addingTimeInterval(-TimeIntervals.secondsInSixMonths) // 6 months ago
            ),
            Review(
                title: "Basic Functionality",
                content: """
                It does what it promises but nothing extraordinary. \
                Would like to see more features.
                """,
                rating: Defaults.averageRating,
                author: "Lisa Martinez",
                date: Date().addingTimeInterval(-TimeIntervals.secondsInYear) // 1 year ago
            )
        ]
    }
}
