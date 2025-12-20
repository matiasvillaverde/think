import Foundation
@preconcurrency import UserNotifications

/// Manages local notifications for background downloads across all platforms
internal actor DownloadNotificationManager {
    private let notificationCenter: NotificationCenterProtocol
    private let logger: ModelDownloaderLogger

    internal init(notificationCenter: NotificationCenterProtocol = RealNotificationCenter()) {
        self.notificationCenter = notificationCenter
        self.logger = ModelDownloaderLogger(
            subsystem: "com.think.modeldownloader",
            category: "DownloadNotificationManager"
        )
    }

    /// Request notification permission from the user
    internal func requestNotificationPermission() async -> Bool {
        await logger.debug("Requesting notification permission")

        do {
            let granted: Bool = try await notificationCenter.requestAuthorization(
                options: [.alert, .sound, .badge]
            )

            await logger.info("Notification permission request result", metadata: [
                "granted": granted
            ])

            return granted
        } catch {
            await logger.error("Failed to request notification permission", error: error)
            return false
        }
    }

    /// Check current notification authorization status
    internal func getNotificationAuthorizationStatus() async -> UNAuthorizationStatus {
        let settings: NotificationSettings = await notificationCenter.notificationSettings()
        await logger.debug("Current notification authorization", metadata: [
            "status": settings.authorizationStatus.rawValue
        ])
        return settings.authorizationStatus
    }

    /// Schedule a notification for download completion
    internal func scheduleDownloadCompleteNotification(
        for downloadId: UUID,
        modelId: String,
        customTitle: String? = nil
    ) async {
        await logger.debug("Scheduling download completion notification", metadata: [
            "downloadId": downloadId.uuidString,
            "modelId": modelId,
            "hasCustomTitle": customTitle != nil
        ])

        // Check authorization first
        let status: UNAuthorizationStatus = await getNotificationAuthorizationStatus()
        guard status == .authorized else {
            await logger.debug("Notifications not authorized, skipping", metadata: [
                "status": status.rawValue
            ])
            return
        }

        let content: UNMutableNotificationContent = UNMutableNotificationContent()
        content.title = customTitle ?? "Model Download Complete"
        content.body = "Model '\(modelId)' is ready to use"
        content.sound = .default

        // Add platform-specific customizations
        #if os(iOS)
        content.badge = 1
        #endif

        // Create identifier for this notification
        let identifier: String = "modeldownload-\(downloadId.uuidString)"

        // Schedule immediate delivery (for background completion)
        let request: UNNotificationRequest = UNNotificationRequest(
            identifier: identifier,
            content: content,
            trigger: nil // Immediate delivery
        )

        do {
            try await notificationCenter.add(request)
            await logger.info("Download completion notification scheduled", metadata: [
                "downloadId": downloadId.uuidString,
                "identifier": identifier
            ])
        } catch {
            await logger.error("Failed to schedule notification", error: error, metadata: [
                "downloadId": downloadId.uuidString
            ])
        }
    }

    /// Schedule a notification for download failure
    internal func scheduleDownloadFailedNotification(
        for downloadId: UUID,
        modelId: String,
        error: Error
    ) async {
        await logger.debug("Scheduling download failure notification", metadata: [
            "downloadId": downloadId.uuidString,
            "modelId": modelId
        ])

        // Check authorization first
        let status: UNAuthorizationStatus = await getNotificationAuthorizationStatus()
        guard status == .authorized else {
            await logger.debug("Notifications not authorized, skipping", metadata: [
                "status": status.rawValue
            ])
            return
        }

        let content: UNMutableNotificationContent = UNMutableNotificationContent()
        content.title = "Model Download Failed"
        content.body = "Download of '\(modelId)' failed. Tap to retry."
        content.sound = .default

        // Create identifier for this notification
        let identifier: String = "modeldownload-failed-\(downloadId.uuidString)"

        // Schedule immediate delivery
        let request: UNNotificationRequest = UNNotificationRequest(
            identifier: identifier,
            content: content,
            trigger: nil
        )

        do {
            try await notificationCenter.add(request)
            await logger.info("Download failure notification scheduled", metadata: [
                "downloadId": downloadId.uuidString,
                "identifier": identifier
            ])
        } catch {
            await logger.error("Failed to schedule failure notification", error: error, metadata: [
                "downloadId": downloadId.uuidString
            ])
        }
    }

    /// Cancel a specific notification
    internal func cancelNotification(for downloadId: UUID) async {
        let identifiers: [String] = [
            "modeldownload-\(downloadId.uuidString)",
            "modeldownload-failed-\(downloadId.uuidString)"
        ]

        await logger.debug("Cancelling notifications", metadata: [
            "downloadId": downloadId.uuidString,
            "identifiers": identifiers
        ])

        notificationCenter.removePendingNotificationRequests(withIdentifiers: identifiers)
        notificationCenter.removeDeliveredNotifications(withIdentifiers: identifiers)

        await logger.debug("Notifications cancelled", metadata: [
            "downloadId": downloadId.uuidString
        ])
    }

    /// Cancel all ModelDownloader notifications
    internal func cancelAllNotifications() async {
        await logger.info("Cancelling all ModelDownloader notifications")

        // Get all pending notifications
        let pendingRequests: [UNNotificationRequest] = await notificationCenter.pendingNotificationRequests()
        let modelDownloadIdentifiers: [String] = pendingRequests
            .compactMap { request in
                request.identifier.hasPrefix("modeldownload-") ? request.identifier : nil
            }

        // Get all delivered notifications
        let deliveredNotifications: [UNNotification] = await notificationCenter.deliveredNotifications()
        let deliveredModelDownloadIdentifiers: [String] = deliveredNotifications
            .compactMap { notification in
                notification.request.identifier.hasPrefix("modeldownload-") ? notification.request.identifier : nil
            }

        let allIdentifiers: Set<String> = Set(modelDownloadIdentifiers + deliveredModelDownloadIdentifiers)

        if !allIdentifiers.isEmpty {
            notificationCenter.removePendingNotificationRequests(withIdentifiers: Array(allIdentifiers))
            notificationCenter.removeDeliveredNotifications(withIdentifiers: Array(allIdentifiers))

            await logger.info("Cancelled ModelDownloader notifications", metadata: [
                "count": allIdentifiers.count
            ])
        } else {
            await logger.debug("No ModelDownloader notifications to cancel")
        }
    }

    /// Schedule a generic notification
    internal func scheduleNotification(
        title: String,
        body: String,
        identifier: String
    ) async {
        await logger.debug("Scheduling notification", metadata: [
            "title": title,
            "identifier": identifier
        ])

        // Check authorization first
        let status: UNAuthorizationStatus = await getNotificationAuthorizationStatus()
        guard status == .authorized else {
            await logger.debug("Notifications not authorized, skipping", metadata: [
                "status": status.rawValue
            ])
            return
        }

        let content: UNMutableNotificationContent = UNMutableNotificationContent()
        content.title = title
        content.body = body
        content.sound = .default

        // Add platform-specific customizations
        #if os(iOS)
        content.badge = 1
        #endif

        // Schedule immediate delivery
        let request: UNNotificationRequest = UNNotificationRequest(
            identifier: identifier,
            content: content,
            trigger: nil // Immediate delivery
        )

        do {
            try await notificationCenter.add(request)
            await logger.info("Notification scheduled", metadata: [
                "identifier": identifier
            ])
        } catch {
            await logger.error("Failed to schedule notification", error: error, metadata: [
                "identifier": identifier
            ])
        }
    }

    /// Schedule a notification for individual model completion
    internal func scheduleModelCompletionNotification(
        modelName: String,
        modelSize: Int64
    ) async {
        await logger.debug("Scheduling model completion notification", metadata: [
            "modelName": modelName,
            "modelSize": modelSize
        ])

        // Check authorization first
        let status: UNAuthorizationStatus = await getNotificationAuthorizationStatus()
        guard status == .authorized else {
            await logger.debug("Notifications not authorized, skipping", metadata: [
                "status": status.rawValue
            ])
            return
        }

        let content: UNMutableNotificationContent = UNMutableNotificationContent()
        content.title = "\(modelName) Downloaded"

        // Format size nicely
        let formatter: ByteCountFormatter = ByteCountFormatter()
        formatter.countStyle = .binary
        let sizeString: String = formatter.string(fromByteCount: modelSize)
        content.body = "Your \(sizeString) model is ready to use!"
        content.sound = .default

        // Add platform-specific customizations
        #if os(iOS)
        content.badge = 1
        #endif

        // Create unique identifier for this model
        let identifier: String = "model-complete-\(modelName)-\(Date().timeIntervalSince1970)"

        // Schedule immediate delivery
        let request: UNNotificationRequest = UNNotificationRequest(
            identifier: identifier,
            content: content,
            trigger: nil // Immediate delivery
        )

        do {
            try await notificationCenter.add(request)
            await logger.info("Model completion notification scheduled", metadata: [
                "modelName": modelName,
                "identifier": identifier
            ])
        } catch {
            await logger.error("Failed to schedule model notification", error: error, metadata: [
                "modelName": modelName
            ])
        }
    }

    /// Handle notification tap (for future implementation)
    internal func handleNotificationResponse(_ response: UNNotificationResponse) async {
        let identifier: String = response.notification.request.identifier

        await logger.info("Handling notification response", metadata: [
            "identifier": identifier,
            "actionIdentifier": response.actionIdentifier
        ])

        // Extract download ID from identifier
        if identifier.hasPrefix("modeldownload-") {
            let downloadIdString: String = String(identifier.dropFirst("modeldownload-".count))
            if let downloadId: UUID = UUID(uuidString: downloadIdString) {
                await logger.debug("Extracted download ID from notification", metadata: [
                    "downloadId": downloadId.uuidString
                ])

                // Future: Could trigger download retry, open app to specific model, etc.
            }
        }
    }
}
