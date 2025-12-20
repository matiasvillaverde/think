import SwiftUI
#if canImport(UIKit)
    import UIKit
    import UserNotifications
#endif

// MARK: - NotificationPermissionView

public struct NotificationPermissionView: View {
    @Environment(\.openURL)
    private var openURL: OpenURLAction

    @Binding public var showNotificationPermission: Bool
    @Binding public var notificationStatus: UNAuthorizationStatus
    public let modelId: UUID?
    public let onPermissionGranted: () -> Void

    // MARK: - Initialization

    public init(
        showNotificationPermission: Binding<Bool>,
        notificationStatus: Binding<UNAuthorizationStatus>,
        modelId: UUID?,
        onPermissionGranted: @escaping () -> Void
    ) {
        _showNotificationPermission = showNotificationPermission
        _notificationStatus = notificationStatus
        self.modelId = modelId
        self.onPermissionGranted = onPermissionGranted
    }

    // MARK: - Layout Constants

    private enum Layout {
        static let buttonSpacing: CGFloat = 16
        static let cornerRadius: CGFloat = 12
        static let dividerSpacing: CGFloat = 8
        static let iconSize: CGFloat = 48
    }

    public var body: some View {
        VStack(spacing: Layout.buttonSpacing) {
            Divider()

            notificationContent
                .padding()
                .background(Color.backgroundSecondary)
                .cornerRadius(Layout.cornerRadius)
        }
        .transition(.move(edge: .bottom).combined(with: .opacity))
    }

    private var notificationContent: some View {
        VStack(spacing: Layout.dividerSpacing) {
            notificationIcon
            notificationTexts
            notificationButtons
        }
    }

    private var notificationIcon: some View {
        Image(systemName: "bell.badge")
            .accessibilityLabel("Notification icon")
            .font(.system(size: Layout.iconSize))
            .foregroundColor(.accentColor)
    }

    private var notificationTexts: some View {
        VStack(spacing: Layout.dividerSpacing) {
            Text("Get notified when download completes", bundle: .module)
                .font(.headline)
                .multilineTextAlignment(.center)

            Text("""
            You can close the app and we'll notify you when \
            your model is ready to use.
            """, bundle: .module)
                .font(.subheadline)
                .foregroundColor(.textSecondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal)
        }
    }

    @ViewBuilder private var notificationButtons: some View {
        if notificationStatus == .denied {
            settingsButton

            Text("Notifications are disabled. Enable them in Settings.", bundle: .module)
                .font(.caption)
                .foregroundColor(.iconAlert)
        } else {
            enableNotificationsButton
        }
    }

    private var settingsButton: some View {
        Button {
            #if os(iOS)
                if let url = URL(string: UIApplication.openSettingsURLString) {
                    openURL(url)
                }
            #endif
        } label: {
            Label("Open Settings", systemImage: "gear")
        }
        .buttonStyle(.borderedProminent)
        .controlSize(.large)
    }

    private var enableNotificationsButton: some View {
        Button {
            requestNotificationPermission()
        } label: {
            Label("Enable Notifications", systemImage: "bell")
        }
        .buttonStyle(.borderedProminent)
        .controlSize(.large)
    }

    #if os(iOS)
        private func requestNotificationPermission() {
            Task {
                let center: UNUserNotificationCenter = UNUserNotificationCenter.current()

                do {
                    let granted: Bool = try await center.requestAuthorization(
                        options: [.alert, .sound, .badge]
                    )

                    await MainActor.run {
                        notificationStatus = granted ? .authorized : .denied

                        if granted {
                            showNotificationPermission = false
                            onPermissionGranted()
                        }
                    }
                } catch {
                    // Failed to request notification permission
                    // Error is handled silently as permission denial is acceptable
                }
            }
        }
    #else
        private func requestNotificationPermission() {
            // No-op on non-iOS platforms
        }
    #endif
}
