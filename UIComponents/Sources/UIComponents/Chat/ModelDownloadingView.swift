import Abstractions
import Database
import OSLog
import SwiftUI
#if canImport(UIKit)
    import UIKit
    @preconcurrency import UserNotifications
#else
    // Define UNAuthorizationStatus for non-iOS platforms
    public enum UNAuthorizationStatus: Int {
        case authorized = 2
        case denied = 1
        case ephemeral = 4
        case notDetermined = 0
        case provisional = 3
    }
#endif

// MARK: - ModelDownloadingView

public struct ModelDownloadingView: View {
    @Environment(\.modelActionsViewModel)
    private var modelActions: ModelDownloaderViewModeling

    @Environment(\.openURL)
    private var openURL: OpenURLAction

    @State private var showNotificationPermission: Bool = false
    @State private var notificationStatus: UNAuthorizationStatus = .notDetermined

    private let logger: Logger = .init(
        subsystem: Bundle.main.bundleIdentifier ?? "",
        category: "ModelDownloadingView"
    )

    // MARK: - Layout Constants

    private enum Layout {
        static let maxWidth: CGFloat = 600
        static let spacing: CGFloat = 24
        static let buttonSpacing: CGFloat = 16
        static let titleSpacing: CGFloat = 8
        static let progressCircleSize: CGFloat = 120
        static let pauseIconSize: CGFloat = 40
        static let dividerSpacing: CGFloat = 8
        static let percentageMultiplier: Int = 100
        static let notificationDelaySeconds: Double = 3.0
    }

    // MARK: - Properties

    @Bindable public var chat: Chat

    // MARK: - Initialization

    public init(chat: Chat) {
        self.chat = chat
    }

    // MARK: - Body

    public var body: some View {
        VStack(spacing: Layout.spacing) {
            Spacer()

            if let downloadingModel = currentlyDownloadingModel {
                titleSection(model: downloadingModel)

                progressSection(model: downloadingModel)

                if showNotificationPermission {
                    NotificationPermissionView(
                        showNotificationPermission: $showNotificationPermission,
                        notificationStatus: $notificationStatus,
                        modelId: currentlyDownloadingModel?.id
                    ) {
                        #if os(iOS)
                            if let model = currentlyDownloadingModel {
                                scheduleDownloadNotification(for: model)
                            }
                        #endif
                    }
                }
            }

            Spacer()
        }
        .frame(maxWidth: Layout.maxWidth)
        .padding()
        #if canImport(UIKit)
            .onAppear {
                UIApplication.shared.isIdleTimerDisabled = true
                checkNotificationStatus()
            }
            .onDisappear {
                UIApplication.shared.isIdleTimerDisabled = false
            }
        #endif
    }

    // MARK: - View Components

    private func titleSection(model: Model) -> some View {
        VStack(spacing: Layout.titleSpacing) {
            Text(titleText(for: model.state ?? .notDownloaded))
                .font(.largeTitle)
                .bold()
                .foregroundColor(.textPrimary)
                .multilineTextAlignment(.center)

            Text(subtitleText(for: model.state ?? .notDownloaded))
                .font(.body)
                .foregroundColor(.textSecondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal)
        }
    }

    private func progressSection(model: Model) -> some View {
        ModelActionButton(model: model)
            .transition(AnyTransition.opacity)
    }

    // MARK: - Helper Methods

    private func titleText(for state: Model.State) -> String {
        switch state {
        case .downloadingActive:
            String(localized: "Downloading Model", bundle: .module)

        case .downloadingPaused:
            String(localized: "Download Paused", bundle: .module)

        // No error state in Model.State anymore

        default:
            String(localized: "Preparing Download", bundle: .module)
        }
    }

    private func subtitleText(for state: Model.State) -> String {
        switch state {
        case .downloadingActive:
            String(
                localized: "Once the download is complete, chat will start automatically.",
                bundle: .module
            )

        case .downloadingPaused:
            String(
                localized: "Resume to continue. Close app and resume later.",
                bundle: .module
            )

        // No error state in Model.State anymore

        default:
            String(localized: "Preparing to download the AI model...", bundle: .module)
        }
    }

    private func formattedBytes(_ bytes: Int64) -> String {
        ByteCountFormatter.string(fromByteCount: bytes, countStyle: .file)
    }

    #if os(iOS) || os(visionOS)
        private func checkNotificationStatus() {
            Task {
                let center: UNUserNotificationCenter = UNUserNotificationCenter.current()
                let settings: UNNotificationSettings = await center.notificationSettings()

                await MainActor.run {
                    notificationStatus = settings.authorizationStatus

                    // Show notification prompt after a delay if downloading
                    if settings.authorizationStatus == .notDetermined,
                        currentlyDownloadingModel?.state?.isDownloadingActive == true {
                        Task {
                            try? await Task.sleep(
                                for: .seconds(Layout.notificationDelaySeconds)
                            )
                            showNotificationPermission = true
                        }
                    }
                }
            }
        }

        private func scheduleDownloadNotification(for model: Model) {
            // BackgroundDownloadManager automatically schedules notifications
            // when downloads complete or fail. This method is called after
            // the user grants notification permissions to ensure the system
            // can display download completion notifications.
            logger.info("Notification permissions granted for model: \(model.name)")
        }
    #endif

    // MARK: - Helper Properties

    private var currentlyDownloadingModel: Model? {
        if chat.languageModel.state?.isDownloading == true {
            return chat.languageModel
        }
        if chat.imageModel.state?.isDownloading == true {
            return chat.imageModel
        }
        return nil
    }
}

// MARK: - Preview

#if DEBUG
    #Preview {
        @Previewable @State var chat: Chat = Chat.preview
        ModelDownloadingView(chat: chat)
    }
#endif
