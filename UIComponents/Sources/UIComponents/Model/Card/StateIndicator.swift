import SwiftUI

internal struct StateIndicator: View {
    let icon: String
    let text: String
    let color: Color

    var body: some View {
        VStack(spacing: DesignConstants.Spacing.small) {
            Image(systemName: icon)
                .font(.system(size: DesignConstants.Size.iconSmall))
                .foregroundColor(color)
                .accessibilityLabel(text)
            Text(text)
                .font(.caption2)
                .bold()
                .multilineTextAlignment(.center)
                .lineLimit(DesignConstants.Font.lineLimit)
                .minimumScaleFactor(DesignConstants.Font.scaleFactor)
                .foregroundColor(color)
        }
    }
}

#Preview {
    StateIndicator(
        icon: "checkmark.circle.fill",
        text: String(localized: "Available", bundle: .module),
        color: Color.marketingSecondary
    )
    StateIndicator(
        icon: "exclamationmark.circle.fill",
        text: "error",
        color: Color.iconAlert
    )
    StateIndicator(
        icon: "checkmark.circle.fill",
        text: String(localized: "Selected", bundle: .module),
        color: Color.iconConfirmation
    )
}
