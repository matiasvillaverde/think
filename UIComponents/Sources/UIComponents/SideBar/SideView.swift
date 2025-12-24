import Abstractions
import Database
import SwiftData
import SwiftUI

// swiftlint:disable no_grouping_extension

public struct SideView: View {
    // MARK: - Properties

    @Environment(\.chatViewModel)
    private var chatViewModel: ChatViewModeling

    @State var hasInitialized: Bool = false // swiftlint:disable:this private_swiftui_state
    @Binding var isPerformingDelete: Bool

    @StateObject private var alertManager: AlertManager = .init()

    @Binding var selectedPersonality: Personality?

    let animationDuration: Double = 0.3
    let smallDuration: Double = 0.1

    // Query to fetch all personalities
    @Query(animation: .easeInOut)
    var personalities: [Personality]

    // Environment values
    @Environment(\.isSearching)
    private var isSearching: Bool

    @Environment(\.dismissSearch)
    private var dismissSearch: DismissSearchAction

    @Environment(\.generator)
    var viewModel: ViewModelGenerating

    @Environment(\.modelActionsViewModel)
    var modelActions: ModelDownloaderViewModeling

    // MARK: - Body

    public var body: some View {
        list
            .navigationSplitViewColumnWidth(
                min: Layout.minSplitViewWidth,
                ideal: Layout.idealSplitViewWidth
            )
            .toolbar {
                if let personality = selectedPersonality {
                    SideViewToolbar(
                        isSearching: isSearching,
                        dismissSearch: dismissSearch,
                        personality: personality
                    )
                }
            }
            .searchable(
                text: $searchText,
                placement: .sidebar,
                prompt: String(localized: "Search Personalities...", bundle: .module)
            )
            .onChange(of: personalities) { _, _ in
                if !isPerformingDelete {
                    autoSelectFirstPersonality()
                }
            }
            .onChange(of: selectedPersonality) { _, newPersonality in
                handlePersonalitySelection(newPersonality)
            }
            .task {
                initialSetup()
            }
    }

    private var list: some View {
        List(selection: $selectedPersonality) {
            PersonalitySections(
                featuredPersonalities: featuredPersonalities,
                activePersonalities: activePersonalities,
                inactivePersonalities: inactivePersonalities,
                alertManager: alertManager
            )
        }
        .listStyle(.sidebar)
        .animation(.easeInOut(duration: animationDuration), value: personalities)
        .alert(
            String(
                localized: "Clear Conversation?",
                bundle: .module,
                comment: "Title for clear conversation confirmation alert"
            ),
            isPresented: $alertManager.showingClearConversationAlert
        ) {
            clearConversationAlertButtons
        } message: {
            Text(
                String(
                    localized: "This will delete all messages.",
                    bundle: .module,
                    comment: "Message for clear conversation confirmation alert"
                )
            )
        }
        .alert(
            String(
                localized: "Delete Personality?",
                bundle: .module,
                comment: "Title for personality deletion confirmation alert"
            ),
            isPresented: $alertManager.showingDeletePersonalityAlert
        ) {
            deletePersonalityAlertButtons
        } message: {
            Text(
                String(
                    localized: "This will delete this personality and conversations.",
                    bundle: .module,
                    comment: "Message for personality deletion confirmation alert"
                )
            )
        }
    }

    private var clearConversationAlertButtons: some View {
        Group {
            Button(
                String(localized: "Cancel", bundle: .module, comment: "Button label"),
                role: .cancel
            ) {
                alertManager.reset()
            }

            Button(
                String(localized: "Clear", bundle: .module, comment: "Button label"),
                role: .destructive
            ) {
                if let personality = alertManager.personalityToModify {
                    let personalityId: UUID = personality.id
                    alertManager.reset()

                    Task(priority: .userInitiated) {
                        await chatViewModel.clearConversation(personalityId: personalityId)
                    }
                } else {
                    alertManager.reset()
                }
            }
        }
    }

    private var deletePersonalityAlertButtons: some View {
        Group {
            Button(
                String(localized: "Cancel", bundle: .module, comment: "Button label"),
                role: .cancel
            ) {
                alertManager.reset()
            }

            Button(
                String(localized: "Delete", bundle: .module, comment: "Button label"),
                role: .destructive
            ) {
                if let personality = alertManager.personalityToModify {
                    let personalityId: UUID = personality.id

                    isPerformingDelete = true
                    alertManager.reset()

                    DispatchQueue.main.asyncAfter(deadline: .now() + animationDuration) {
                        Task {
                            await chatViewModel.deletePersonality(personalityId: personalityId)

                            DispatchQueue.main.asyncAfter(
                                deadline: .now() + animationDuration
                            ) {
                                isPerformingDelete = false
                            }
                        }
                    }
                } else {
                    alertManager.reset()
                }
            }
        }
    }

    // MARK: - Search States

    @State var searchText: String = "" // swiftlint:disable:this private_swiftui_state
}

// MARK: - Personality Filtering

extension SideView {
    /// Featured personalities (isFeature == true)
    var featuredPersonalities: [Personality] {
        filteredPersonalities
            .filter(\.isFeature)
            .sorted { $0.name < $1.name }
    }

    /// Personalities with recent conversations, sorted by last message date
    var activePersonalities: [Personality] {
        filteredPersonalities
            .filter { !$0.isFeature && $0.hasConversation }
            .sorted { ($0.lastMessageDate ?? .distantPast) > ($1.lastMessageDate ?? .distantPast) }
    }

    /// Personalities without conversations
    var inactivePersonalities: [Personality] {
        filteredPersonalities
            .filter { !$0.isFeature && !$0.hasConversation }
            .sorted { $0.name < $1.name }
    }

    /// Apply search filter
    var filteredPersonalities: [Personality] {
        guard !searchText.isEmpty else {
            return personalities
        }
        return personalities.filter { personality in
            personality.name.localizedCaseInsensitiveContains(searchText) ||
            personality.displayDescription.localizedCaseInsensitiveContains(searchText)
        }
    }
}

// MARK: - Helper Methods

extension SideView {
    func autoSelectFirstPersonality() {
        let sortedPersonalities: [Personality] =
            featuredPersonalities + activePersonalities + inactivePersonalities

        guard let firstPersonality = sortedPersonalities.first else {
            selectedPersonality = nil
            return
        }

        if selectedPersonality?.id != firstPersonality.id {
            DispatchQueue.main.asyncAfter(deadline: .now() + smallDuration) {
                selectedPersonality = firstPersonality
            }
        }
    }

    func handlePersonalitySelection(_ personality: Personality?) {
        guard let personality else {
            return
        }

        Task(priority: .userInitiated) {
            await chatViewModel.selectPersonality(personalityId: personality.id)
        }
    }

    func initialSetup() {
        if !hasInitialized {
            hasInitialized = true
            if selectedPersonality == nil, !personalities.isEmpty {
                selectedPersonality = featuredPersonalities.first ?? personalities.first
            }
        }
    }
}

// swiftlint:enable no_grouping_extension

#if DEBUG
#Preview(traits: .modifier(PreviewDatabase())) {
    @Previewable @State var personality: Personality?
    @Previewable @State var isPerformingDelete: Bool = false
    SideView(isPerformingDelete: $isPerformingDelete, selectedPersonality: $personality)
}
#endif
