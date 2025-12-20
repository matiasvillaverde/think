import SwiftUI

/// A view that displays an error state with a try again button.
internal struct TryAgainView: View {
    private enum Constants {
        static let buttonHeight: CGFloat = 42
    }

    let errorMessage: String
    let tryAgainAction: () -> Void

    var body: some View {
        ContentUnavailableView {
            Label(.networkError, symbol: .exclamationmarkTriangle)
        } description: {
            Text(errorMessage)
        } actions: {
            Button(
                action: tryAgainAction
            ) {
                Text(.tryAgain)
                    .font(.headline.weight(.semibold))
                    .frame(height: Constants.buttonHeight)
                    .padding(.horizontal)
            }
            .buttonStyle(.bordered)
            .buttonBorderShape(.roundedRectangle)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(.background)
    }
}

#Preview {
    TryAgainView(
        errorMessage: "Failed to load content"
    ) {
        // Action to be performed when try again is tapped
    }
}
