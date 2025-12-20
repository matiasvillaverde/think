// PersonalityGroupView.swift
import Database
import SwiftUI

/// View displaying a group of personalities with a title
internal struct PersonalityGroupView: View {
    let personalities: [Personality]
    let title: String
    let onSelectPersonality: (Personality) -> Void

    private enum Layout {
        static let minItemWidth: CGFloat = 160
    }

    var body: some View {
        VStack(alignment: .leading, spacing: DesignConstants.Spacing.medium) {
            Text(title)
                .font(.title)
                .bold()
                .foregroundColor(Color.textPrimary)
                .padding(.leading, DesignConstants.Spacing.small)

            LazyVGrid(
                columns: [
                    GridItem(
                        .adaptive(minimum: Layout.minItemWidth),
                        spacing: DesignConstants.Spacing.medium
                    )
                ],
                spacing: DesignConstants.Spacing.medium
            ) {
                ForEach(personalities) { personality in
                    PersonalityCardView(personality: personality)
                        .onTapGesture {
                            onSelectPersonality(personality)
                        }
                        .accessibilityAddTraits(.isButton)
                }
            }
        }
        Spacer()
    }
}
