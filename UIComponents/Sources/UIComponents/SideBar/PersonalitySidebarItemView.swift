import Database
import SwiftUI

public struct PersonalitySidebarItemView: View {
    // MARK: - Properties

    @Bindable var personality: Personality

    // MARK: - Body

    public var body: some View {
        HStack(spacing: PersonalitySidebarLayout.rowSpacing) {
            personalityIcon

            VStack(alignment: .leading, spacing: PersonalitySidebarLayout.verticalSpacing) {
                Text(personality.name)
                    .font(.headline)
                    .lineLimit(PersonalitySidebarLayout.lineLimit)

                if personality.hasConversation, let lastDate = personality.lastMessageDate {
                    Text(lastDate, style: .relative)
                        .font(.caption)
                        .foregroundStyle(Color.textSecondary)
                }
            }

            Spacer()
        }
        .padding(.vertical, PersonalitySidebarLayout.verticalPadding)
    }

    private var personalityIcon: some View {
        ZStack {
            Circle()
                .fill(personality.tintColor.opacity(PersonalitySidebarLayout.iconBackgroundOpacity))
                .frame(
                    width: PersonalitySidebarLayout.iconSize,
                    height: PersonalitySidebarLayout.iconSize
                )

            if let imageName = personality.imageName {
                Image(imageName, bundle: .module)
                    .resizable()
                    .scaledToFill()
                    .frame(
                        width: PersonalitySidebarLayout.iconSize,
                        height: PersonalitySidebarLayout.iconSize
                    )
                    .clipShape(Circle())
                    .accessibilityLabel(personality.name)
            } else {
                Image(systemName: "person.circle.fill")
                    .resizable()
                    .scaledToFit()
                    .frame(
                        width: PersonalitySidebarLayout.iconImageSize,
                        height: PersonalitySidebarLayout.iconImageSize
                    )
                    .foregroundStyle(personality.tintColor)
                    .accessibilityLabel(personality.name)
            }
        }
    }
}

// MARK: - Layout Constants

private enum PersonalitySidebarLayout {
    static let iconSize: CGFloat = 32
    static let iconImageSize: CGFloat = 16
    static let rowSpacing: CGFloat = 12
    static let verticalSpacing: CGFloat = 2
    static let verticalPadding: CGFloat = 4
    static let lineLimit: Int = 1
    static let iconBackgroundOpacity: Double = 0.2
}

#if DEBUG
#Preview {
    PersonalitySidebarItemView(personality: .preview)
}
#endif
