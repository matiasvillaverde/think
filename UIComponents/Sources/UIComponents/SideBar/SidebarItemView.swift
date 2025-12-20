import Database
import SwiftUI

public struct SidebarItemView: View {
    // MARK: - Properties

    @Bindable var chat: Chat

    // MARK: - Body

    public var body: some View {
        VStack(alignment: .leading, spacing: Layout.spacing) {
            Text(chat.name)
                .font(.headline)
                .lineLimit(Layout.lineLimit)
        }
        .padding(.vertical, Layout.spacing)
    }
}

#if DEBUG
    #Preview {
        @Previewable @State var chat: Chat = .preview
        SidebarItemView(chat: chat)
    }
#endif
