import SwiftUI

@MainActor
extension LocalizedStringKey {
    /// Localized string key for "Give a Rating" button text.
    internal static let giveARating: LocalizedStringKey = .init("Give a Rating")
    /// Localized string key for "Help Us Grow!" screen title.
    internal static let helpUsGrow: LocalizedStringKey = .init("Help Us Grow!")
    /// Localized string key for "Maybe Later" button text.
    internal static let maybeLater: LocalizedStringKey = .init("Maybe Later")
    /// Localized string key for "Network Error!" message.
    internal static let networkError: LocalizedStringKey = .init("Network Error!")
    /// Localized string key for "Be the first to rate us!" message.
    internal static let noRatingsYet: LocalizedStringKey = .init(
        "Be the first to rate us!"
    )
    /// Localized string key for "No Reviews Yet" message.
    internal static let noReviewsYet: LocalizedStringKey = .init("No Reviews Yet")
    /// Localized string key for "Try Again" button text.
    internal static let tryAgain: LocalizedStringKey = .init("Try Again")

    /// Creates a localized string key for ratings count display.
    /// - Parameter count: The number of ratings to display.
    /// - Returns: A localized string key for the ratings count.
    static func ratings(_ count: Int) -> LocalizedStringKey {
        .init("\(count) ratings")
    }
}
