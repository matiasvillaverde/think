import SwiftUI

internal struct ToastView: View {
    // MARK: - Constants

    private enum Constants {
        static let horizontalSpacing: CGFloat = 12
        static let spacerMinLength: CGFloat = 10
        static let contentPadding: CFloat = 16
        static let horizontalPadding: CGFloat = 16
        static let cornerRadius: CGFloat = 8
        static let borderOpacity: Double = 0.6
    }

    let style: ToastStyle
    let message: String
    let width: CGFloat
    let onCancelTapped: () -> Void

    init(
        style: ToastStyle,
        message: String,
        width: CGFloat = .infinity,
        onCancelTapped: @escaping () -> Void
    ) {
        self.style = style
        self.message = message
        self.width = width
        self.onCancelTapped = onCancelTapped
    }

    var body: some View {
        HStack(alignment: .center, spacing: Constants.horizontalSpacing) {
            Image(systemName: style.iconFileName)
                .foregroundColor(style.themeColor)
                .accessibilityLabel(
                    String(
                        localized: "Notification image",
                        bundle: .module,
                        comment: "Accessibility label for the image of a notification"
                    )
                )
            Text(message)
                .font(Font.caption)
                .foregroundColor(Color.textPrimary)

            Spacer(minLength: Constants.spacerMinLength)

            Button {
                onCancelTapped()
            } label: {
                Image(systemName: "xmark")
                    .foregroundColor(style.themeColor)
                    .accessibilityLabel(
                        String(
                            localized: "Notification image",
                            bundle: .module,
                            comment: "Accessibility label for the image of a notification"
                        )
                    )
            }
        }
        .padding()
        .frame(minWidth: 0, maxWidth: width)
        .background(Color.backgroundPrimary)
        .cornerRadius(Constants.cornerRadius)
        .padding(.horizontal, Constants.horizontalPadding)
    }
}

public struct Toast: Equatable {
    // MARK: - Constants

    private enum Constants {
        static let defaultDuration: Double = 3
        static let defaultWidth: Double = .infinity
    }

    public let style: ToastStyle
    public let message: String
    public let duration: Double
    public let width: Double

    public init(
        style: ToastStyle,
        message: String,
        duration: Double = 3,
        width: Double = .infinity
    ) {
        self.style = style
        self.message = message
        self.duration = duration
        self.width = width
    }
}

// MARK: - Preview

#Preview {
    ToastView(style: .success, message: "Chat Created") {
        // Action handled
    }
    ToastView(style: .error, message: "Error ocurred") {
        // Action handled
    }
    ToastView(style: .info, message: "Some info") {
        // Action handled
    }
    ToastView(style: .warning, message: "Warning info") {
        // Action handled
    }
}
