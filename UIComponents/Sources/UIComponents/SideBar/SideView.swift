import Abstractions
import Database
import SwiftData
import SwiftUI

public struct SideView: View {
    // MARK: - Properties

    @Environment(\.chatViewModel)
    private var chatViewModel: ChatViewModeling

    @State var hasInitialized: Bool = false // swiftlint:disable:this private_swiftui_state
    @Binding var isPerformingDelete: Bool

    @StateObject private var alertManager: AlertManager = .init()

    @Binding var selectedChat: Chat? {
        didSet {
            guard let chat = selectedChat else {
                return
            }
            Task(priority: .userInitiated) {
                await chatViewModel.addWelcomeMessage(chatId: chat.id)
            }
        }
    }

    let animationDuration: Double = 0.3
    let smallDuration: Double = 0.1

    // Query to fetch all chats in reverse chronological order
    @Query(
        sort: \Chat.createdAt,
        order: .reverse,
        animation: .easeInOut
    )
    var chats: [Chat]

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
                if let selectedChat {
                    SideViewToolbar(
                        isSearching: isSearching,
                        dismissSearch: dismissSearch,
                        chat: selectedChat
                    )
                }
            }
            .searchable(
                text: $searchText,
                tokens: $searchTokens,
                placement: .sidebar,
                prompt: String(localized: "Search Chats...", bundle: .module)
            ) { token in
                Text(token.displayName)
            }
            .searchSuggestions {
                SearchSuggestionsContent(
                    searchText: searchText,
                    modelSuggestions: availableModelDisplayNames()
                )
            }
            .searchScopes($searchScope) {
                SearchScopesContent()
            }
            .onChange(of: chats) { _, newChats in
                // Only auto-select if we're not in the middle of a deletion
                if !isPerformingDelete {
                    autoSelectFirstChat(newChats: newChats)
                }
            }
            .onChange(of: selectedChat) { _, newChat in
                loadSelectedChat(newChat: newChat)
            }
            .task {
                initialSetup()
            }
    }

    private var list: some View {
        List(selection: $selectedChat) {
            PersonalitiesListView()
            ChatSections(
                chatsToday: chatsToday,
                chatsYesterday: chatsYesterday,
                chatsPast: chatsPast,
                alertManager: alertManager
            )
        }
        .listStyle(.sidebar)
        .animation(.easeInOut(duration: animationDuration), value: chats)
        .alert(
            String(
                localized: "Rename Chat",
                bundle: .module,
                comment: "Title for chat rename alert"
            ),
            isPresented: $alertManager.showingRenameAlert
        ) {
            Group {
                TextField(
                    String(
                        localized: "New title",
                        bundle: .module
                    ),
                    text: $alertManager.renameText
                )

                Button(
                    String(localized: "Cancel", bundle: .module, comment: "Button label"),
                    role: .cancel
                ) {
                    alertManager.reset()
                }

                Button(
                    String(localized: "Save", bundle: .module, comment: "Button label")
                ) {
                    if let chat = alertManager.chatToModify {
                        let trimmedName: String = alertManager.renameText.trimmingCharacters(
                            in: .whitespacesAndNewlines
                        )

                        Task(priority: .userInitiated) {
                            await chatViewModel.rename(chatId: chat.id, newName: trimmedName)
                        }
                    }
                    alertManager.reset()
                }
            }
        } message: {
            Text(
                String(
                    localized: "Enter a new chat title",
                    bundle: .module,
                    comment: "Message for chat rename alert"
                )
            )
        }
        .alert(
            String(
                localized: "Delete Chat?",
                bundle: .module,
                comment: "Title for chat deletion confirmation alert"
            ),
            isPresented: $alertManager.showingDeleteAlert
        ) {
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
                    if let chat = alertManager.chatToModify {
                        // Store the ID locally
                        let chatId: UUID = chat.id

                        // Prevent auto-selection during deletion
                        isPerformingDelete = true

                        // Reset the alert state
                        alertManager.reset()

                        // Perform deletion after a brief delay
                        DispatchQueue.main.asyncAfter(deadline: .now() + animationDuration) {
                            Task {
                                await chatViewModel.delete(chatId: chatId)

                                // Re-enable auto-selection after operation completes
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
        } message: {
            Text(
                String(
                    localized: "Are you sure you want to delete this chat?",
                    bundle: .module,
                    comment: "Message for chat deletion confirmation alert"
                )
            )
        }
    }

    // MARK: - Search States

    @State var searchText: String = "" // swiftlint:disable:this private_swiftui_state
    @State var searchScope: ChatSearchScope = .all // swiftlint:disable:this private_swiftui_state
    @State var searchTokens: [ModelToken] = [] // swiftlint:disable:this private_swiftui_state
}

#if DEBUG
    #Preview(traits: .modifier(PreviewDatabase())) {
        @Previewable @State var chat: Chat?
        @Previewable @State var isPerformingDelete: Bool = false
        SideView(isPerformingDelete: $isPerformingDelete, selectedChat: $chat)
    }
#endif
