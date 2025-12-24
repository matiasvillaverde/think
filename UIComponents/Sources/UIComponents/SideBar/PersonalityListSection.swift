import Database
import SwiftUI

public struct PersonalityListSection: View {
    // MARK: - Properties

    let personalities: [Personality]
    let alertManager: AlertManager

    // MARK: - Body

    public var body: some View {
        ForEach(personalities, id: \.id) { personality in
            NavigationLink(value: personality) {
                PersonalitySidebarItemView(personality: personality)
            }
            .swipeActions(allowsFullSwipe: true) {
                if personality.isCustom {
                    Button {
                        onClearConversation(personality: personality)
                    } label: {
                        Label(
                            String(
                                localized: "Clear",
                                bundle: .module,
                                comment: "Sidebar clear conversation action"
                            ),
                            systemImage: "trash"
                        )
                    }
                    .tint(Color.orange)
                }
            }
            .contextMenu {
                contextMenuClearConversation(personality: personality)
                if personality.isCustom {
                    contextMenuDelete(personality: personality)
                }
            }
        }
    }

    private func contextMenuClearConversation(personality: Personality) -> some View {
        Button {
            onClearConversation(personality: personality)
        } label: {
            Label(
                String(
                    localized: "Clear Conversation",
                    bundle: .module,
                    comment: "Context menu clear conversation action"
                ),
                systemImage: "trash"
            )
            .font(.system(size: Layout.contextMenuIconSize))
        }
    }

    private func contextMenuDelete(personality: Personality) -> some View {
        Button(role: .destructive) {
            onDelete(personality: personality)
        } label: {
            Label(
                String(
                    localized: "Delete Personality",
                    bundle: .module,
                    comment: "Context menu delete personality action"
                ),
                systemImage: "person.badge.minus"
            )
            .font(.system(size: Layout.contextMenuIconSize))
        }
    }

    private func onClearConversation(personality: Personality) {
        alertManager.prepareClearConversation(personality: personality)
    }

    private func onDelete(personality: Personality) {
        alertManager.prepareDeletePersonality(personality: personality)
    }
}

#if DEBUG
#Preview {
    PersonalityListSection(personalities: [Personality.preview], alertManager: AlertManager())
}
#endif
