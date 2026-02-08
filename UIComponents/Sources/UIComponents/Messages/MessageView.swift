import Abstractions
import Database
import MarkdownUI
import SwiftUI

// MARK: - Layout Constants

/// Layout constants for message display components
public enum MessageLayout {
    static let defaultSpacing: CGFloat = 10
    static let bubblePadding: CGFloat = 10
    static let headerBottomPadding: CGFloat = 5
    static let avatarSize: CGFloat = 20
    static let headerTopPadding: CGFloat = 15
    static let fileAttachmentWidth: CGFloat = 200
    static let verticalPadding: CGFloat = 8
    static let cornerRadius: CGFloat = 10
    static let alertDismissDelay: TimeInterval = 3
    static let fileSectionSpacing: CGFloat = 12
    static let tapCount: Int = 2
    static let spacing: CGFloat = 4
    static let uuidPrefixLength: Int = 8
}

// MARK: - MessageView

public struct MessageView: View {
    @Environment(\.openWindow)
    private var openWindow: OpenWindowAction

    @Environment(\.notificationViewModel)
    private var notificationViewModel: ViewModelNotifying

    @State private var showingSelectionView: Bool = false
    @State private var showingThinkingView: Bool = false
    @State private var showingStatsView: Bool = false
    @State private var showingAlert: Bool = false
    @Namespace private var botMessageID: Namespace.ID
    @Bindable var message: Message

    public var body: some View {
        VStack(alignment: .leading, spacing: MessageLayout.defaultSpacing) {
            userBubble()
            assistantContent()
            assistantImage()
        }
        .padding()
        .listRowSeparator(.hidden)
        .textSelection(.enabled)
        .alert(String(localized: "Copied", bundle: .module), isPresented: $showingAlert) {
            // No buttons needed
        } message: {
            Text("The message has been copied to the clipboard.", bundle: .module)
        }
    }

    // MARK: - View Components

    @ViewBuilder
    private func userBubble() -> some View {
        if let userText = message.userInput, !userText.isEmpty {
            UserBubbleView(
                message: message,
                showingSelectionView: $showingSelectionView,
                showingStatsView: $showingStatsView,
                showingThinkingView: $showingThinkingView,
                showAlert: showAlertWithDelay
            )
            .onTapGesture(count: MessageLayout.tapCount) {
                copyTextToClipboard(userText)
                showAlertWithDelay()
            }
            .accessibilityAddTraits(.isButton)
        }
    }

    @ViewBuilder
    private func assistantContent() -> some View {
        AssistantBubbleView(
            message: message,
            showingSelectionView: $showingSelectionView,
            showingThinkingView: $showingThinkingView,
            showingStatsView: $showingStatsView,
            copyTextAction: copyTextToClipboard,
            shareTextAction: shareText
        )
        .onTapGesture(count: MessageLayout.tapCount) {
            // Try to copy from final channel if it exists
            if let channels = message.channels,
                let finalChannel = channels.first(where: { $0.type == .final }),
                !finalChannel.content.isEmpty {
                copyTextToClipboard(finalChannel.content)
                showAlertWithDelay()
            } else if let response = message.response, !response.isEmpty {
                // Fallback to legacy response if available
                copyTextToClipboard(response)
                showAlertWithDelay()
            }
        }
        .accessibilityAddTraits(.isButton)
    }

    @ViewBuilder
    private func assistantImage() -> some View {
        if message.responseImage != nil {
            AssistantImageBubbleView(
                message: message
            )
        }
    }

    // MARK: - Clipboard & Alerts

    private func copyTextToClipboard(_ text: String) {
        #if os(iOS) || os(visionOS)
            UIPasteboard.general.string = text
        #elseif os(macOS)
            NSPasteboard.general.clearContents()
            NSPasteboard.general.setString(text, forType: .string)
        #endif

        Task(priority: .userInitiated) {
            await notificationViewModel.showMessage(
                String(
                    localized: "Copied to clipboard",
                    bundle: .module,
                    comment: "Copied text to clipboard notification"
                )
            )
        }
    }

    private func showAlertWithDelay() {
        showingAlert = true
        Task {
            try? await Task.sleep(for: .seconds(MessageLayout.alertDismissDelay))
            await MainActor.run {
                showingAlert = false
            }
        }
    }

    // MARK: - Sharing

    private func shareText(_ text: String) {
        #if os(iOS) || os(visionOS)
            guard let rootVC = UIApplication.shared.connectedScenes
                .compactMap({ $0 as? UIWindowScene })
                .first?
                .windows
                .first?
                .rootViewController else { return }

            let activityVC: UIActivityViewController = UIActivityViewController(
                activityItems: [text],
                applicationActivities: nil
            )
            rootVC.present(activityVC, animated: true)
        #elseif os(macOS)
            guard let window = NSApplication.shared.windows.first?.contentView else {
                return
            }

            let sharingPicker: NSSharingServicePicker = NSSharingServicePicker(items: [text])
            sharingPicker.show(relativeTo: .zero, of: window, preferredEdge: .minY)
        #endif
    }
}

// MARK: - Preview

#if DEBUG
    #Preview {
        @Previewable @State var messages: [Message] = Message.allPreviews

        ScrollView {
            LazyVStack {
                ForEach(messages) { message in
                    MessageView(message: message)
                }
            }
        }
    }
#endif
