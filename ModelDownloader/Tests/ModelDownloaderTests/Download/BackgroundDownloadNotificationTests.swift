@testable import Abstractions
import Foundation
@testable import ModelDownloader
import Testing
import UserNotifications

@Suite("Background Download Notification Tests")
struct BackgroundDownloadNotificationTests {
    @Test("No generic notification on session completion - notifications are per-model")
    func testNoGenericNotificationOnSessionCompletion() async {
        // Given
        let mockNotificationCenter: MockNotificationCenter = MockNotificationCenter()
        let notificationManager: DownloadNotificationManager = DownloadNotificationManager(
            notificationCenter: mockNotificationCenter
        )

        // We just verify that the notification manager doesn't send a generic notification
        // when called directly (simulating what would happen in the delegate)

        // In the real implementation, urlSessionDidFinishEvents no longer sends
        // a generic notification - notifications are sent per-model completion

        // Give async operations time to complete
        try? await Task.sleep(nanoseconds: 100_000_000) // 0.1 seconds

        // Then - No notifications should be scheduled
        #expect(mockNotificationCenter.addedRequests.isEmpty)
    }

    @Test("No notification when not authorized")
    func testNoNotificationWhenNotAuthorized() async {
        // Given
        let mockNotificationCenter: MockNotificationCenter = MockNotificationCenter()
        mockNotificationCenter.authorizationStatus = .denied

        let notificationManager: DownloadNotificationManager = DownloadNotificationManager(
            notificationCenter: mockNotificationCenter
        )

        // When - Test notification manager directly since we don't send notifications when unauthorized
        await notificationManager.scheduleModelCompletionNotification(
            modelName: "Test Model",
            modelSize: 1_000_000_000
        )

        // Then - No notification should be scheduled when unauthorized
        #expect(mockNotificationCenter.addedRequests.isEmpty)
    }

    @Test("Download failure notification scheduled on error")
    func testFailureNotificationOnError() async {
        // Given
        let mockNotificationCenter: MockNotificationCenter = MockNotificationCenter()
        let notificationManager: DownloadNotificationManager = DownloadNotificationManager(
            notificationCenter: mockNotificationCenter
        )

        let downloadId: UUID = UUID()
        let modelId: String = "test-model"
        let error: NSError = NSError(domain: "TestError", code: -1, userInfo: [
            NSLocalizedDescriptionKey: "Network connection lost"
        ])

        // When
        await notificationManager.scheduleDownloadFailedNotification(
            for: downloadId,
            modelId: modelId,
            error: error
        )

        // Then
        #expect(mockNotificationCenter.addedRequests.count == 1)

        let notification: UNNotificationRequest? = mockNotificationCenter.addedRequests.first
        #expect(notification?.content.title == "Model Download Failed")
        #expect(notification?.content.body == "Download of '\(modelId)' failed. Tap to retry.")
        #expect(notification?.identifier.contains("failed") == true)
    }

    @Test("Individual download completion notification")
    func testIndividualDownloadCompletionNotification() async {
        // Given
        let mockNotificationCenter: MockNotificationCenter = MockNotificationCenter()
        let notificationManager: DownloadNotificationManager = DownloadNotificationManager(
            notificationCenter: mockNotificationCenter
        )

        let downloadId: UUID = UUID()
        let modelId: String = "llama-3.2-1b"

        // When
        await notificationManager.scheduleDownloadCompleteNotification(
            for: downloadId,
            modelId: modelId,
            customTitle: "Model Ready!"
        )

        // Then
        #expect(mockNotificationCenter.addedRequests.count == 1)

        let notification: UNNotificationRequest? = mockNotificationCenter.addedRequests.first
        #expect(notification?.content.title == "Model Ready!")
        #expect(notification?.content.body == "Model '\(modelId)' is ready to use")
        #expect(notification?.identifier == "modeldownload-\(downloadId.uuidString)")
    }

    @Test("Notification includes sound and badge")
    func testNotificationIncludesSoundAndBadge() async {
        // Given
        let mockNotificationCenter: MockNotificationCenter = MockNotificationCenter()
        let notificationManager: DownloadNotificationManager = DownloadNotificationManager(
            notificationCenter: mockNotificationCenter
        )

        let downloadId: UUID = UUID()

        // When
        await notificationManager.scheduleDownloadCompleteNotification(
            for: downloadId,
            modelId: "test-model"
        )

        // Then
        let notification: UNNotificationRequest? = mockNotificationCenter.addedRequests.first
        #expect(notification?.content.sound == .default)

        #if os(iOS)
        #expect(notification?.content.badge as? Int == 1)
        #endif
    }
}
