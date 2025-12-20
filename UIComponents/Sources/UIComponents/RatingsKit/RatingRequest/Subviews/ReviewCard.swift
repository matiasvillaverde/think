import SwiftUI

internal struct ReviewCard: View {
    private enum Constants {
        static let titleSpacing: CGFloat = 6
        static let authorSpacing: CGFloat = 12
        static let memojiSize: CGFloat = 40
        static let detailSpacing: CGFloat = 6
        static let cornerRadius: CGFloat = 12
        static let starSpacing: CGFloat = 1.5
        static let maxStars: Int = 5
    }

    let review: Review
    let memoji: Image

    init(
        review: Review,
        memoji: Image
    ) {
        self.review = review
        self.memoji = memoji
    }

    var body: some View {
        VStack(alignment: .leading, spacing: .zero) {
            VStack(alignment: .leading, spacing: Constants.titleSpacing) {
                Text(review.title)
                    .font(.headline.weight(.semibold))
                Text(review.content)
                    .font(.body)
                Spacer(minLength: .zero)
            }
            HStack(spacing: Constants.authorSpacing) {
                memoji
                    .resizable()
                    .frame(width: Constants.memojiSize, height: Constants.memojiSize)
                    .background(.background.secondary)
                    .clipShape(.circle)

                VStack(alignment: .leading, spacing: Constants.detailSpacing) {
                    starRatingView

                    HStack(spacing: .zero) {
                        Text(review.author)
                            .foregroundStyle(.primary)
                        Text(" • ") + Text(review.date.relativeTime)
                            .foregroundStyle(.secondary)
                    }
                    .font(.caption.weight(.medium))
                }
            }
        }
        .padding()
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            .background.secondary,
            in: .rect(cornerRadius: Constants.cornerRadius)
        )
    }

    private var starRatingView: some View {
        HStack(spacing: Constants.starSpacing) {
            ForEach(1 ... Constants.maxStars, id: \.self) { index in
                Image(systemName: "star")
                    .symbolVariant(index <= review.rating ? .fill : .none)
                    .imageScale(.small)
                    .foregroundColor(.orange)
                    .accessibilityLabel(
                        index <= review.rating ? "Filled star" : "Empty star"
                    )
            }
        }
    }
}

#Preview {
    List {
        ReviewCard(
            review: .mock(),
            memoji: Image(MemojiAssets.person1)
        )
        .listRowSeparator(.hidden)

        ReviewCard(
            review: .mock(),
            memoji: Image(MemojiAssets.person1)
        )
        .redacted(reason: .placeholder)
        .listRowSeparator(.hidden)
    }
    .scrollContentBackground(.hidden)
    .listSectionSeparator(.hidden)
    .listSectionSpacingIfAvailable()
    .listStyle(.plain)
    .padding()
}
