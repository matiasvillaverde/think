import Database
import SwiftUI

// MARK: - MessagesContainerView

public struct MessagesContainerView: View {
    @Environment(\.controller)
    private var controller: ViewInteractionController

    @Bindable var chat: Chat

    public var body: some View {
        MessagesView(chat: chat)
        #if os(iOS) || os(visionOS)
            .background(Color.backgroundSecondary)
        #endif
    }
}
