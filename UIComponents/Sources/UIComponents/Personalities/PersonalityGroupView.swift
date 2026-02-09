// PersonalityGroupView.swift
import DataAssets
import Database
import SwiftUI

/// View displaying a group of personalities with a title
internal struct PersonalityGroupView: View {
    let personalities: [Personality]
    let title: String
    let onSelectPersonality: (Personality) -> Void

    private enum Layout {
        static let minItemWidth: CGFloat = 160
        static let defaultPopularityRank: Int = .max
    }

    private typealias Instruction = SystemInstruction

    private func popularityRank(_ personality: Personality) -> Int {
        Self.popularityOrder.firstIndex(of: personality.systemInstruction)
            ?? Layout.defaultPopularityRank
    }

    private static let popularityOrder: [Instruction] = [
        .empatheticFriend,
        .englishAssistant,
        .workCoach,
        .lifeCoach,
        .supportivePsychologist,
        .teacher,
        .dietitian,
        .butler,
        .mother,
        .father
    ]

    var body: some View {
        let orderedPersonalities: [Personality] = personalities.sorted { first, second in
            let firstRank: Int = popularityRank(first)
            let secondRank: Int = popularityRank(second)
            if firstRank != secondRank {
                return firstRank < secondRank
            }
            return first.name.localizedCaseInsensitiveCompare(second.name) == .orderedAscending
        }

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
                ForEach(orderedPersonalities) { personality in
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
