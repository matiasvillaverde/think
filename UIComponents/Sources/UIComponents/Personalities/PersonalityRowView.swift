import Abstractions
import Database
import SwiftUI

// MARK: - Layout Constants

internal enum PersonalityLayout {
    static let iconSize: CGFloat = 48
    static let iconImageSize: CGFloat = 13
    static let exploreIconImageSize: CGFloat = 16
    static let titleStackSpacing: CGFloat = 2
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
        Button(action: action) { rowContent }
        .buttonStyle(.plain)
        .accessibilityElement(children: .combine)
        .accessibilityLabel(String(localized: "\(personality.name) personality", bundle: .module))
        .accessibilityAddTraits(.isButton)
    }

    private var rowContent: some View {
        HStack(spacing: PersonalityLayout.rowSpacing) {
            avatar
            titleStack
            Spacer()
        }
        .contentShape(Rectangle())
        .padding(.vertical, PersonalityLayout.rowVerticalPadding)
    }

    private var avatar: some View {
        ZStack {
            Circle()
                .fill(personality.tintColor.opacity(PersonalityLayout.backgroundOpacity))
                .frame(
                    width: PersonalityLayout.iconSize,
                    height: PersonalityLayout.iconSize
                )

            Image(personality.imageName ?? "think", bundle: .module)
                .resizable()
                .interpolation(.high)
                .scaledToFill()
                .accessibilityHidden(true)
                .frame(
                    width: PersonalityLayout.iconSize,
                    height: PersonalityLayout.iconSize
                )
                .clipShape(Circle())
                .font(.system(size: PersonalityLayout.iconImageSize, weight: .medium))
                .foregroundStyle(personality.tintColor)
        }
    }

    private var titleStack: some View {
        VStack(alignment: .leading, spacing: PersonalityLayout.titleStackSpacing) {
            Text(personality.name)
                .font(.headline)
                .foregroundStyle(Color.textPrimary)
                .lineLimit(1)

            Text(personality.displayDescription)
                .font(.caption)
                .foregroundStyle(Color.textSecondary)
                .lineLimit(1)
        }
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
