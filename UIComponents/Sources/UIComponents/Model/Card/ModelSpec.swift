import SwiftUI

internal struct ModelSpec: View {
    let value: String

    var body: some View {
        VStack(alignment: .leading, spacing: DesignConstants.Spacing.small) {
            HStack(spacing: DesignConstants.Spacing.small) {
                Text(value)
                    .font(.caption2)
                    .foregroundColor(Color.textPrimary)
                    .bold()
            }
            Text("RAM Required", bundle: .module)
                .font(.caption2)
                .foregroundColor(Color.textSecondary)
        }
        .padding(.top, DesignConstants.Spacing.medium)
        .accessibilityElement(children: .combine)
        .accessibilityLabel(
            String(
                localized: "RAM Required: \(value)",
                bundle: .module,
                comment: "Accessibility label for the RAM required text"
            )
        )
    }
}

#Preview {
    ModelSpec(value: "4GB")
}
