import Abstractions
import Database
import SwiftUI

// MARK: - Layout Constants

internal enum PersonalityLayout {
    static let iconSize: CGFloat = 40
    static let iconImageSize: CGFloat = 13
    static let exploreIconImageSize: CGFloat = 16
    static let rowSpacing: CGFloat = 12
    static let rowVerticalPadding: CGFloat = 6
    static let cornerRadius: CGFloat = 8
    static let listSpacing: CGFloat = 4
    static let listPadding: CGFloat = 16
    static let cardCornerRadius: CGFloat = 12
    static let dividerInset: CGFloat = 68
    static let strokeWidth: CGFloat = 0.5
    static let backgroundOpacity: Double = 0.2
    static let cardStrokeOpacity: Double = 0.5
}

// MARK: - Personality Row View

internal struct PersonalityRowView: View {
    @Environment(\.chatViewModel)
    var viewModel: ChatViewModeling

    let personality: Personality

    var body: some View {
        Button(action: action) {
            HStack(spacing: PersonalityLayout.rowSpacing) {
                ZStack {
                    Circle()
                        .fill(personality.tintColor.opacity(PersonalityLayout.backgroundOpacity))
                        .frame(
                            width: PersonalityLayout.iconSize,
                            height: PersonalityLayout.iconSize
                        )

                    Image(personality.imageName ?? "think", bundle: .module)
                        .resizable()
                        .scaledToFill()
                        .frame(
                            width: PersonalityLayout.iconSize,
                            height: PersonalityLayout.iconSize
                        )
                        .clipShape(Circle())
                        .font(.system(size: PersonalityLayout.iconImageSize, weight: .medium))
                        .foregroundStyle(personality.tintColor)
                }

                Text(personality.name)
                    .font(.body)
                    .foregroundStyle(Color.textPrimary)

                Spacer()
            }
            .contentShape(Rectangle())
            .padding(.vertical, PersonalityLayout.rowVerticalPadding)
        }
        .buttonStyle(.plain)
        .accessibilityElement(children: .combine)
        .accessibilityLabel(String(localized: "\(personality.name) personality", bundle: .module))
        .accessibilityAddTraits(.isButton)
    }

    private func action() {
        Task(priority: .userInitiated) {
            await viewModel.addChatWith(personality: personality.id)
        }
    }
}

#Preview {
    PersonalityRowView(personality: .default)
}
