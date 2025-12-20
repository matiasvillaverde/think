import Database
import SwiftUI

// **MARK: - User Context Menu**
public struct UserContextMenu: View {
    let textToCopy: String
    @Bindable var message: Message
    @Binding var showingSelectionView: Bool
    @Binding var showingThinkingView: Bool
    @Binding var showingStatsView: Bool

    public var body: some View {
        Group {
            Button(action: { shareText(textToCopy) }, label: {
                Label(String(
                    localized: "Share",
                    bundle: .module,
                    comment: "Action button label for sharing text"
                ), systemImage: "square.and.arrow.up")
            })

            Button(action: { copyTextToClipboard(textToCopy) }, label: {
                Label(String(
                    localized: "Copy",
                    bundle: .module,
                    comment: "Action button label for copying text"
                ), systemImage: "doc.on.doc")
            })

            #if os(iOS) || os(visionOS)
                Button(action: {
                    showingSelectionView = true
                }, label: {
                    Label(String(
                        localized: "Select",
                        bundle: .module,
                        comment: "Action button label for selecting text"
                    ), systemImage: "text.cursor")
                })
            #endif

            thinkingButtonIfAvailable
            statisticsButtonIfAvailable
        }
    }

    private var thinkingButtonIfAvailable: some View {
        Group {
            if message.thinking != nil {
                Button(action: {
                    showingThinkingView.toggle()
                }, label: {
                    Label(String(
                        localized: "Thinking process",
                        bundle: .module,
                        comment: "Button label to view the thinking process"
                    ), systemImage: "brain.filled.head.profile")
                })
            }
        }
    }

    private var statisticsButtonIfAvailable: some View {
        Group {
            if message.metrics != nil {
                Button(action: { showingStatsView = true }, label: {
                    Label(String(
                        localized: "Statistics",
                        bundle: .module,
                        comment: "Button label to view the statistics"
                    ), systemImage: "chart.bar.fill")
                })
            }
        }
    }

    private func copyTextToClipboard(_ text: String) {
        #if os(iOS)
            UIPasteboard.general.string = text
        #elseif os(macOS)
            let pasteboard: NSPasteboard = NSPasteboard.general
            pasteboard.clearContents()
            pasteboard.setString(text, forType: .string)
        #endif
    }

    private func shareText(_ text: String) {
        #if os(iOS) || os(visionOS)
            let activityVC: UIActivityViewController = UIActivityViewController(
                activityItems: [text],
                applicationActivities: nil
            )
            if
                let scene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
                let rootVC = scene.windows.first?.rootViewController {
                rootVC.present(activityVC, animated: true)
            }
        #elseif os(macOS)
            let sharingPicker: NSSharingServicePicker = NSSharingServicePicker(items: [text])
            if let window = NSApplication.shared.windows.first {
                sharingPicker.show(
                    relativeTo: .zero,
                    of: window.contentView ?? NSView(),
                    preferredEdge: .minY
                )
            }
        #endif
    }
}
