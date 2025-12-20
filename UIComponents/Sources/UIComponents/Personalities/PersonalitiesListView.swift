import Abstractions
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
        sort: \Personality.name,
        animation: .easeInOut
    )
    private var featured: [Personality]

    var body: some View {
        VStack {
            ForEach(featured) { personality in
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
