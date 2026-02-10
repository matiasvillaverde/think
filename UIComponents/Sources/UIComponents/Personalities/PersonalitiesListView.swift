import Abstractions
import DataAssets
import Database
import SwiftData
import SwiftUI

// MARK: - Personalities List View

internal struct PersonalitiesListView: View {
    @Environment(\.chatViewModel)
    var viewModel: ChatViewModeling
    @State private var showExploreAgents: Bool = false

    @Query(
        filter: #Predicate<Personality> { $0.isFeature == true },
        animation: .easeInOut
    )
    private var featured: [Personality]

    private static let featuredOrder: [SystemInstruction] = [
        .empatheticFriend,       // Buddy
        .relationshipAdvisor,    // Girlfriend
        .lifeCoach,              // Life Coach
        .butler                  // Butler
    ]

    var body: some View {
        VStack {
            ForEach(orderedFeatured) { personality in
                PersonalityRowView(
                    personality: personality
                )
            }
            ExplorePersonalitiesRowView(action: onExploreAgents)
        }
        .sheet(isPresented: $showExploreAgents) {
            PersonalityListContentView(
                isShowing: $showExploreAgents,
                onSelectPersonality: onSelectPersonality(_:)
            )
        }
    }

    private func onExploreAgents() {
        showExploreAgents = true
    }

    private var orderedFeatured: [Personality] {
        featured.sorted { left, right in
            rank(for: left) < rank(for: right)
        }
    }

    private func rank(for personality: Personality) -> Int {
        guard let idx = Self.featuredOrder.firstIndex(of: personality.systemInstruction) else {
            return Int.max
        }
        return idx
    }

    private func onSelectPersonality(_ personality: Personality) {
        showExploreAgents = false
        Task(priority: .userInitiated) {
            await viewModel.addChatWith(personality: personality.id)
        }
    }
}

#Preview {
    PersonalitiesListView()
}
