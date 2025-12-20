import Abstractions
import Database
import SwiftData
import SwiftUI

// **MARK: - Support Buttons**
public struct SupportButtons: View {
    // **MARK: - Constants**
    private enum Constants {
        static let minHeight: CGFloat = 40
        static let minHeightBug: CGFloat = 30
        static let buttonSpacing: CGFloat = 10
        static let buttonHorizontalPadding: CGFloat = 12
        static let buttonVerticalPadding: CGFloat = 2
        static let backgroundOpacity: Double = 0.15
        static let textOpacity: Double = 1.0
        static let hoverBackgroundOpacity: Double = 0.25
        static let cornerRadius: CGFloat = 8
        static let buttonWidth: CGFloat = 180
        static let bugReportDelay: TimeInterval = 0.1
        static let lineLimit: Int = 1
        static let animationDuration: Double = 0.3
        static let opacity: CGFloat = 0.5
        static let progressViewScale: CGFloat = 0.8
    }

    // **MARK: - Environment**
    @Environment(\.chatViewModel)
    private var chatViewModel: ChatViewModeling

    // Query to fetch all chats
    @Query(sort: \Chat.createdAt, order: .reverse)
    private var chats: [Chat]

    // **MARK: - Properties**
    @State private var showingEmailAlert: Bool = false
    @State private var showingDeleteAllAlert: Bool = false
    @State private var isReportingBug: Bool = false
    @State private var isSettingsHovered: Bool = false
    @State private var isReportBugHovered: Bool = false
    @State private var isDeleteAllHovered: Bool = false
    @State private var isPerformingDelete: Bool = false

    // **MARK: - Body**
    public var body: some View {
        HStack(alignment: .center, spacing: Constants.buttonSpacing) {
            ReportBugButton(
                isReportingBug: $isReportingBug,
                showingEmailAlert: $showingEmailAlert
            )
            #if os(iOS)
                settingsButton
            #endif
            deleteAllButton
        }
        .frame(maxWidth: .infinity)
        .padding()
        .background(Color.clear)
        .alert(isPresented: $showingEmailAlert) {
            emailAlert
        }
        .alert(
            String(
                localized: "Delete All Data?",
                bundle: .module,
                comment: "Title for delete all data confirmation alert"
            ),
            isPresented: $showingDeleteAllAlert
        ) {
            Group {
                Button(
                    String(localized: "Cancel", bundle: .module, comment: "Button label"),
                    role: .cancel
                ) {
                    showingDeleteAllAlert = false
                }

                Button(
                    String(localized: "Delete All", bundle: .module, comment: "Button label"),
                    role: .destructive
                ) {
                    deleteAllChats()
                    showingDeleteAllAlert = false
                }
            }
        } message: {
            // swiftlint:disable line_length
            Text(
                String(
                    localized: "This action will permanently delete all chats and cannot be undone. Are you sure you want to continue?",
                    bundle: .module,
                    comment: "Message for delete all data confirmation alert"
                )
            )
            // swiftlint:enable line_length
        }
    }

    // **MARK: - Settings Button**
    private var settingsButton: some View {
        #if os(iOS) || os(visionOS)
            // iOS implementation - Navigate to custom SettingsView
            NavigationLink(destination: SettingsView()) {
                buttonContent
            }
            .buttonStyle(PlainButtonStyle())
            .onHover { hovering in
                isSettingsHovered = hovering
            }
        #else
            SettingsLink {
                buttonContent
            }
            .buttonStyle(PlainButtonStyle())
            .onHover { hovering in
                isSettingsHovered = hovering
            }
        #endif
    }

    // **MARK: - Button Content**
    private var buttonContent: some View {
        ViewThatFits(in: .horizontal) {
            HStack {
                Image(systemName: "gear")
                    .imageScale(.medium)
                    .accessibility(label: Text("Settings icon", bundle: .module))
                Text(String(
                    localized: "Settings",
                    bundle: .module,
                    comment: "Button label for settings"
                ))
                .lineLimit(Constants.lineLimit)
            }
        }
        .font(.body)
        .padding(.vertical, Constants.buttonVerticalPadding)
        .background(
            Color.marketingSecondary.opacity(
                isSettingsHovered
                    ? Constants.hoverBackgroundOpacity : Constants.backgroundOpacity
            )
        )
        .foregroundColor(Color.textSecondary)
        .cornerRadius(Constants.cornerRadius)
    }

    // **MARK: - Delete All Button**
    private var deleteAllButton: some View {
        Button(
            action: {
                guard !isPerformingDelete else {
                    return
                }
                showingDeleteAllAlert = true
            },
            label: {
                deleteAllLabel
                    .background(
                        Color.marketingSecondary.opacity(
                            isDeleteAllHovered
                                ? Constants.hoverBackgroundOpacity : Constants.backgroundOpacity
                        )
                    )
                    .foregroundColor(
                        chats.isEmpty ? Color.textSecondary.opacity(
                            Constants.opacity
                        ) : Color.red
                    )
                    .cornerRadius(Constants.cornerRadius)
            }
        )
        .buttonStyle(PlainButtonStyle())
        .disabled(chats.isEmpty || isPerformingDelete)
        .onHover { hovering in
            isDeleteAllHovered = hovering
        }
    }

    private var deleteAllLabel: some View {
        ViewThatFits(in: .horizontal) {
            HStack {
                if isPerformingDelete {
                    ProgressView()
                        .progressViewStyle(
                            CircularProgressViewStyle(tint: Color.red)
                        )
                        .scaleEffect(Constants.progressViewScale)
                        .accessibility(
                            label: Text("Deleting data", bundle: .module)
                        )
                } else {
                    Image(systemName: "trash.fill")
                        .imageScale(.medium)
                        .accessibility(label: Text("Delete icon", bundle: .module))
                }
                Text(String(
                    localized: "Delete All",
                    bundle: .module,
                    comment: "Button label for deleting all data"
                ))
                .lineLimit(Constants.lineLimit)
            }
        }
        .font(.body)
    }

    private var emailAlert: Alert {
        Alert(
            title: Text(String(
                localized: "Cannot Send Email",
                bundle: .module,
                comment: "Alert title when email cannot be sent"
            )),
            message: Text(String(
                localized: "Your device is not configured to send email.",
                bundle: .module,
                comment: "Alert message when email cannot be sent"
            )),
            dismissButton: .default(Text(String(
                localized: "OK",
                bundle: .module,
                comment: "Button to dismiss alert"
            )))
        )
    }

    // **MARK: - Helper Methods**
    private func deleteAllChats() {
        // Prevent multiple simultaneous deletions
        guard !isPerformingDelete else {
            return
        }

        isPerformingDelete = true

        Task {
            // Delete all chats concurrently
            await chatViewModel.deleteAll()

            // Re-enable the button after all deletions complete
            DispatchQueue.main.asyncAfter(deadline: .now() + Constants.animationDuration) {
                isPerformingDelete = false
            }
        }
    }
}

// **MARK: - Preview**
#if DEBUG
    #Preview {
        NavigationView {
            SupportButtons()
        }
    }
#endif
