import SwiftUI

internal struct RatingView: View {
    private enum Constants {
        static let starCount: Int = 5
        static let itemSpacing: CGFloat = 4
        static let verticalSpacing: CGFloat = 12
        static let sliderPadding: CGFloat = 24
        static let maxRating: Double = 5.0
        static let minRating: Double = 0.0
        static let fullFill: Double = 1.0
        static let emptyFill: Double = 0.0
        static let defaultPreviewRating: Double = 5.0
    }

    private let rating: Double
    private let starCount: Int = Constants.starCount
    private let spacing: CGFloat = Constants.itemSpacing

    init(rating: Double) {
        self.rating = rating
    }

    var body: some View {
        VStack(alignment: .center, spacing: Constants.verticalSpacing) {
            ratingWithLaurels
            starsView
        }
        .font(.title.bold())
    }

    private var ratingWithLaurels: some View {
        HStack(spacing: spacing) {
            Image(systemName: "laurel.leading")
                .accessibilityLabel("Leading laurel")

            Text(rating.formatted(
                .number.precision(.fractionLength(1))
            ))
            .monospaced()

            Image(systemName: "laurel.trailing")
                .accessibilityLabel("Trailing laurel")
        }
    }

    private var starsView: some View {
        HStack(spacing: spacing) {
            ForEach(1 ... starCount, id: \.self) { position in
                starView(for: position)
            }
        }
    }

    private func starView(for position: Int) -> some View {
        Image(systemName: "star")
            .symbolVariant(.fill)
            .imageScale(.small)
            .foregroundStyle(starGradient(for: position))
            .accessibilityLabel("Star \(position)")
    }

    private func starGradient(for position: Int) -> LinearGradient {
        LinearGradient(
            stops: [
                .init(color: .orange, location: getFillRatio(for: position)),
                .init(color: .secondary, location: getFillRatio(for: position))
            ],
            startPoint: .leading,
            endPoint: .trailing
        )
    }

    private func getFillRatio(for position: Int) -> CGFloat {
        let fill: Double = Double(position) - rating
        return min(max(Constants.fullFill - fill, Constants.emptyFill), Constants.fullFill)
    }
}

#Preview {
    @Previewable @State var rating: Double = 5.0

    VStack {
        RatingView(rating: rating)

        Slider(value: $rating, in: 0 ... 5)
    }
    .padding(24)
}
