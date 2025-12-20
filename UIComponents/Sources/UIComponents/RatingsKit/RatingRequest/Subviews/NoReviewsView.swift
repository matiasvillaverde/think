import SwiftUI

internal struct NoReviewsView: View {
    private enum Constants {
        static let aspectRatio: Double = 1.0
        static let cornerRadius: CGFloat = 20
        static let viewPadding: CGFloat = 20
    }

    var body: some View {
        ContentUnavailableView(.noReviewsYet, symbol: .squareAndPencil)
            .aspectRatio(Constants.aspectRatio, contentMode: .fit)
            .frame(maxWidth: .infinity, alignment: .center)
            .background(
                .background.secondary,
                in: .rect(cornerRadius: Constants.cornerRadius)
            )
            .padding(Constants.viewPadding)
    }
}

#Preview {
    NoReviewsView()
}
