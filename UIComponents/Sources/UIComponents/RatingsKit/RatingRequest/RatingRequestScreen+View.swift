import SwiftUI

extension RatingRequestScreen: View {
    private enum Constants {
        static let bodySpacing: CGFloat = 16
        static let headerSpacing: CGFloat = 12
        static let buttonHeight: CGFloat = 42
        static let loadingReviewCount: Int = 5
    }

    public var body: some View {
        VStack(spacing: Constants.bodySpacing) {
            headerSection
            reviewList
                .safeAreaInset(
                    edge: .bottom,
                    content: callToActionSection
                )
        }
        .padding(.vertical)
        .background(.background)
        .overlay(content: errorStateView)
        .task(fetchData)
    }
}

// MARK: Header Section

extension RatingRequestScreen {
    private var headerSection: some View {
        VStack(alignment: .center, spacing: Constants.headerSpacing) {
            titleView
            averageRatingView
            totalRatingsView
        }
    }

    private var titleView: some View {
        Text(configuration.screenTitle)
            .font(.largeTitle.bold())
    }

    private var averageRatingView: some View {
        RatingView(rating: averageRating)
            .redacted(when: state.isLoading)
    }

    @ViewBuilder private var totalRatingsView: some View {
        if isShowingNoRatings {
            Text(.noRatingsYet)
        } else {
            HStack {
                MemojisStack(memojis: configuration.memojis)
                Text(.ratings(totalRatings))
                    .font(.body.weight(.medium))
                    .redacted(when: state.isLoading)
            }
        }
    }
}

// MARK: Review List

extension RatingRequestScreen {
    private var reviewList: some View {
        List {
            if state.isLoading {
                loadingReviewCards
            } else {
                reviewCards
            }
        }
        .scrollContentBackground(.hidden)
        .listSectionSeparator(.hidden)
        .listSectionSpacingIfAvailable()
        .listStyle(.plain)
        .overlay(noReviewsView)
    }

    private var loadingReviewCards: some View {
        ForEach(0 ..< Constants.loadingReviewCount, id: \.self) { _ in
            ReviewCard(review: .mock(), memoji: Image(MemojiAssets.person1))
                .redacted(reason: .placeholder)
                .listRowSeparator(.hidden)
        }
    }

    private var reviewCards: some View {
        ForEach(reviews.indices, id: \.self) { index in
            if let review = reviews[safe: index],
                let memoji = configuration.memojis[safe: index] {
                ReviewCard(review: review, memoji: memoji)
                    .listRowSeparator(.hidden)
            }
        }
    }

    @ViewBuilder private var noReviewsView: some View {
        if isShowingNoReviews {
            NoReviewsView()
        }
    }
}

// MARK: Call to Action Section

extension RatingRequestScreen {
    @ViewBuilder
    private func callToActionSection() -> some View {
        if !state.isLoading {
            VStack(spacing: .zero) {
                primaryButton
                secondaryButton
            }
            .background(.background)
            .transition(.move(edge: .bottom))
        }
    }

    private var primaryButton: some View {
        Button(
            action: ratingRequestAction
        ) {
            Text(configuration.primaryButtonTitle)
                .frame(maxWidth: .infinity)
                .font(.headline.weight(.semibold))
                .frame(height: Constants.buttonHeight)
        }
        .buttonStyle(.borderedProminent)
        .buttonBorderShape(.roundedRectangle)
        .padding()
    }

    @ViewBuilder private var secondaryButton: some View {
        if let secondaryButtonAction {
            Button(
                action: secondaryButtonAction
            ) {
                Text(configuration.secondaryButtonTitle)
                    .font(.subheadline.weight(.medium))
            }
            .buttonStyle(.borderless)
        }
    }
}

// MARK: Error State

extension RatingRequestScreen {
    @ViewBuilder
    private func errorStateView() -> some View {
        if let errorMessage = state.errorMessage {
            TryAgainView(
                errorMessage: errorMessage,
                tryAgainAction: tryAgainAction
            )
        }
    }
}
