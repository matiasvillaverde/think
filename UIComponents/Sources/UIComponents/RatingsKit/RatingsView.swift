import Abstractions
import StoreKit
import SwiftUI

internal struct RatingsView: View {
    @Environment(\.reviewPromptViewModel)
    var viewModel: ReviewPromptManaging

    @Environment(\.requestReview)
    private var requestReview: RequestReviewAction

    @Binding var isRatingsViewPresented: Bool

    var body: some View {
        RatingRequestScreen(
            appId: appStoreID,
            appRatingProvider: YourAppRatingProvider(),
            configuration: RatingScreenConfiguration(screenTitle: randomIndieTitle),
            primaryButtonAction: {
                // Handle when user has requested to leave a rating
                ask()
            },
            secondaryButtonAction: {
                // Handle when user decides to rate later
                Task(priority: .userInitiated) {
                    await MainActor.run {
                        withAnimation(.spring()) {
                            isRatingsViewPresented = false
                        }
                    }
                    await viewModel.userRequestedLater()
                }
            },
            onError: { _ in
                // Handle when user decides to rate later
                Task(priority: .userInitiated) {
                    await viewModel.userRequestedLater()
                }
            }
        )
        .tint(Color.iconConfirmation)
    }

    private var appStoreID: String {
        let infoValue: Any? = Bundle.main.object(forInfoDictionaryKey: "APPSTORE_APP_ID")
        return infoValue as? String ?? "0000000000"
    }

    @MainActor private var randomIndieTitle: LocalizedStringKey {
        let reviewPrompts: [LocalizedStringKey] = [
            LocalizedStringKey("Support Independent Software"),
            LocalizedStringKey("Help Indie Developers Thrive"),
            LocalizedStringKey("Power Independent Innovation"),
            LocalizedStringKey("Your Feedback Fuels Our Progress"),
            LocalizedStringKey("Like the App? Tell the World!"),
            LocalizedStringKey("Help Us Improve—Share Your Thoughts"),
            LocalizedStringKey("Your Opinion Matters—Let Others Know!"),
            LocalizedStringKey("Tell the World What You Think"),
            LocalizedStringKey("Share Your Experience with Others"),
            LocalizedStringKey("Your Voice Helps Others Decide")
        ]
        return reviewPrompts.randomElement() ?? LocalizedStringKey("Power Independent Innovation")
    }

    private func ask() {
        Task(priority: .userInitiated) {
            await MainActor.run {
                isRatingsViewPresented = false
                requestReview()
            }
        }
    }
}

internal struct YourAppRatingProvider: AppRatingProviding {
    private enum Constants {
        static let averageRating: Double = 4.9
        static let totalRatings: Int = 10
        static let reviewRating: Int = 5
        static let reviewRatingBad: Int = 4
    }

    func fetch() throws -> AppRatingResponse {
        AppRatingResponse(
            averageRating: Constants.averageRating,
            totalRatings: Constants.totalRatings,
            reviews: reviews
        )
    }

    private var reviews: [Review] {
        // swiftlint:disable line_length no_magic_numbers
        // Helper to create dates in the past month
        let calendar: Calendar = Calendar.current
        let today: Date = Date()

        let geopoliticalReview: Review = Review(
            title: String(
                localized: "Private AI in Uncertain Times",
                comment: "Title for a review emphasizing privacy in current global context"
            ),
            content: String(
                localized: "In the current geopolitical chaos, having the possibility to use AI privately is invaluable. I support this project because it's both free and high quality. The developer deserves recognition for creating something that puts users first in an era of increasing data surveillance.",
                comment: "Review highlighting the importance of private AI technology in current global situation"
            ),
            rating: Constants.reviewRating,
            author: String(
                localized: "ProudCitizen55",
                comment: "A globally-minded, politically-aware user - use a culturally appropriate name for each locale"
            ),
            date: calendar.date(byAdding: .day, value: -1, to: today) ?? Date()
        )

        let positiveReview: Review = Review(
            title: String(
                localized: "Outstanding App from an Independent Developer",
                comment: "Title for a positive review highlighting an independent developer"
            ),
            content: String(
                localized: "I'm happy to support independent developers like this who prioritize user experience and privacy over monetization. Definitely worth downloading and sharing with friends!",
                comment: "Positive review content praising the app's privacy features, speed, and free availability"
            ),
            rating: Constants.reviewRating,
            author: String(
                localized: "JimMacCurry23",
                comment: "A common name for an app enthusiast - should be translated to a culturally appropriate common name for each locale"
            ),
            date: calendar.date(byAdding: .day, value: -2, to: today) ?? Date()
        )

        let speedAndUIReview: Review = Review(
            title: String(
                localized: "Fast with Clean Interface",
                comment: "Title for a review highlighting speed and UI design"
            ),
            content: String(
                localized: "This app works incredibly fast even on my older device. The UI is very clean and intuitive - no clutter or confusing menus. Everything is exactly where you'd expect it to be, making the app a joy to use daily.",
                comment: "Review praising the app's speed and clean user interface"
            ),
            rating: Constants.reviewRating,
            author: String(
                localized: "TechMinimalist42",
                comment: "A tech-savvy user who appreciates minimalist design - use a culturally appropriate name for each locale"
            ),
            date: calendar.date(byAdding: .day, value: -7, to: today) ?? Date()
        )

        let betaFeedbackReview: Review = Review(
            title: String(
                localized: "Promising Beta with Great Potential",
                comment: "Title for a review acknowledging beta status with constructive feedback"
            ),
            content: String(
                localized: "The app still needs some improvements and I can see that it's in beta. However, the core idea is great and the developer seems responsive to feedback. I'll give 4 stars for now, and I'm excited to see how it evolves.",
                comment: "Review noting the app is in beta with some needed improvements but showing overall enthusiasm"
            ),
            rating: Constants.reviewRatingBad,
            author: String(
                localized: "EarlyAdopter88",
                comment: "A user who tries new technology early - use a culturally appropriate name for each locale"
            ),
            date: calendar.date(byAdding: .day, value: -15, to: today) ?? Date()
        )

        let comparisonReview: Review = Review(
            title: String(
                localized: "Perfect for Quick Tasks with Privacy Focus",
                comment: "Title for a review comparing the app favorably for specific use cases"
            ),
            content: String(
                localized: "Great app for small tasks! While it's not as feature-rich as ChatGPT, it's completely free and respects my privacy, which I really value. No tracking, no accounts needed - just open and use. Perfect for my day-to-day needs.",
                comment: "Review comparing the app to alternatives while highlighting privacy and free access as advantages"
            ),
            rating: Constants.reviewRating,
            author: String(
                localized: "PrivacyFirst2024",
                comment: "A privacy-conscious user - use a culturally appropriate name for each locale"
            ),
            date: calendar.date(byAdding: .day, value: -22, to: today) ?? Date()
        )

        return [
            geopoliticalReview,
            positiveReview,
            speedAndUIReview,
            betaFeedbackReview,
            comparisonReview
        ]
    }
    // swiftlint:enable line_length no_magic_numbers
}

#Preview {
    @Previewable @State var isPresented: Bool = true
    RatingsView(isRatingsViewPresented: $isPresented)
}
