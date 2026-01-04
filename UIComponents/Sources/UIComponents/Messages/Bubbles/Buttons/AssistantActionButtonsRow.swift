import Abstractions
import class Database.Message
import Foundation
import StoreKit
import SwiftUI

/// Type alias for Database.Message to avoid naming conflicts
public typealias DatabaseMessage = Database.Message

// MARK: - Action Buttons Row

/// Displays a row of action buttons for the message
public struct AssistantActionButtonsRow: View {
    @Environment(\.notificationViewModel)
    private var notificationViewModel: ViewModelNotifying

    @Environment(\.requestReview)
    private var requestReview: RequestReviewAction

    @Environment(\.audioViewModel)
    private var audioViewModel: AudioViewModeling

    /// The message to perform actions on
    @Bindable var message: DatabaseMessage

    /// Binding to control the display of the statistics view
    @Binding var showingStatsView: Bool

    /// Binding to control the display of the thinking process view
    @Binding var showingThinkingView: Bool

    /// Action to perform when copying text
    let copyTextAction: (String) -> Void

    /// Action to perform when sharing text
    let shareTextAction: (String) -> Void

    /// The most recent app version that prompted for a review
    @AppStorage("lastVersionPromptedForReview")
    private var lastVersionPromptedForReview: String = ""

    /// Has the user already given a review for this app version
    @AppStorage("hasGivenReview")
    private var hasGivenReview: Bool = false

    public var body: some View {
        HStack(spacing: ButtonConstants.buttonSpacing) {
            createActionButtons()
        }
        .padding(.vertical, ButtonConstants.verticalPadding)
    }

    // MARK: - Button Creation Methods

    /// Creates all action buttons
    private func createActionButtons() -> some View {
        Group {
            createCopyButton()
            createUtilityButtons()
            createSpeakButtons()

            // Show only if the user hasn't review this version
            if !hasGivenReview || getAppVersion() != lastVersionPromptedForReview {
                createFeedbackButtons()
            }
        }
    }

    /// Creates the copy button
    private func createCopyButton() -> some View {
        HoverableActionButton(
            systemName: "doc.on.doc",
            filledSystemName: "checkmark",
            accessibilityLabel: String(
                localized: "Share",
                bundle: .module,
                comment: "Accessibility label for the share button"
            )
        ) {
            copyTextAction(message.response ?? "")
        }
    }

    /// Creates utility buttons (stats, thinking, share)
    private func createUtilityButtons() -> some View {
        Group {
            createStatsButton()
            createThinkingButtonIfNeeded()
            createShareButton()
        }
    }

    /// Creates the statistics button
    private func createStatsButton() -> some View {
        HoverableActionButton(
            systemName: "chart.bar",
            filledSystemName: "chart.bar.fill",
            accessibilityLabel: String(
                localized: "Statistics",
                bundle: .module,
                comment: "Accessibility label for the statistics button"
            ),
            confirmationColor: Color.iconInfo
        ) {
            showingStatsView = true
        }
    }

    /// Creates the thinking process button if thinking data is available
    private func createThinkingButtonIfNeeded() -> some View {
        Group {
            if let thinking = message.thinking, !thinking.isEmpty {
                HoverableActionButton(
                    systemName: "brain",
                    filledSystemName: "brain.fill",
                    accessibilityLabel: String(
                        localized: "Thinking process",
                        bundle: .module,
                        comment: "Accessibility label for the thinking process button"
                    ),
                    confirmationColor: Color.iconInfo
                ) {
                    showingThinkingView = true
                }
            }
        }
    }

    /// Creates the share button
    private func createShareButton() -> some View {
        HoverableActionButton(
            systemName: "square.and.arrow.up",
            filledSystemName: "square.and.arrow.up.fill",
            accessibilityLabel: String(
                localized: "Share",
                bundle: .module,
                comment: "Accessibility label for the share button"
            ),
            confirmationColor: Color.iconConfirmation
        ) {
            shareTextAction(message.response ?? "")
        }
    }

    private func createSpeakButtons() -> some View {
        Group {
            HoverableActionButton(
                systemName: "waveform",
                filledSystemName: "waveform.circle.fill",
                accessibilityLabel: String(
                    localized: "Speak",
                    bundle: .module,
                    comment: "Accessibility label for the Speak out loud button"
                )
            ) {
                Task(priority: .userInitiated) {
                    await audioViewModel.say(message.response ?? "Error")
                }
            }
        }
    }

    /// Creates feedback buttons (like/dislike)
    private func createFeedbackButtons() -> some View {
        Group {
            HoverableActionButton(
                systemName: "hand.thumbsup",
                filledSystemName: "star.fill",
                accessibilityLabel: String(
                    localized: "Like",
                    bundle: .module,
                    comment: "Accessibility label for the Like button"
                )
            ) {
                handleLike()
            }
        }
    }

    private func handleLike() {
        Task(priority: .userInitiated) {
            await notificationViewModel.showMessage(
                String(
                    localized: "Thanks for the 5 stars! ⭐⭐⭐⭐⭐",
                    bundle: .module,
                    comment: "Notification message for liking an assistant response"
                )
            )
        }

        let currentAppVersion: String = getAppVersion()

        // Request review after minimum number of likes and when:
        // 1. User has never given a review, OR
        // 2. User is using a new version of the app since their last review
        if currentAppVersion != lastVersionPromptedForReview {
            presentReview()

            // Store the current version and mark that user gave review
            lastVersionPromptedForReview = currentAppVersion
            hasGivenReview = true
        }
    }

    /// Presents the rating and review request view after a short delay
    private func presentReview() {
        Task {
            // Small delay to avoid interrupting the user
            try? await Task.sleep(for: .seconds(1))
            requestReview()
        }
    }

    func getAppVersion() -> String {
        if let appVersion = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String {
            return appVersion
        }
        return "Unknown"
    }
}

// MARK: - Preview

#if DEBUG
    #Preview {
        @Previewable @State var message: Message = Message.previewWithResponse
        @Previewable @State var showingStatsView: Bool = true

        AssistantActionButtonsRow(
            message: message,
            showingStatsView: $showingStatsView,
            showingThinkingView: $showingStatsView,
            copyTextAction: { _ in
                // no-op
            },
            shareTextAction: { _ in
                // no-op
            }
        )
    }
#endif
