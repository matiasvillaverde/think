@testable import Abstractions
import Foundation
@testable import ModelDownloader
import Testing
import UserNotifications

@Suite("Per-Model Notification Tests")
struct PerModelNotificationTests {
    @Test("Multiple model completion notifications")
    func testMultipleModelCompletionNotifications() async {
        // Given
        let mockNotificationCenter: MockNotificationCenter = MockNotificationCenter()
        let notificationManager: DownloadNotificationManager = DownloadNotificationManager(
            notificationCenter: mockNotificationCenter
        )

        // When - First model completes
        await notificationManager.scheduleModelCompletionNotification(
            modelName: "Llama 3.2 1B",
            modelSize: 1_000_000_000
        )

        // Then - Should have one notification for the first model
        let expectedCount: Int = 1
        #expect(mockNotificationCenter.addedRequests.count == expectedCount)
        let firstNotification: UNNotificationRequest? = mockNotificationCenter.addedRequests.first
        #expect(firstNotification?.content.title == "Llama 3.2 1B Downloaded")
        #expect(firstNotification?.content.body == "Your 953.7 MB model is ready to use!")

        // When - Second model completes
        await notificationManager.scheduleModelCompletionNotification(
            modelName: "Stable Diffusion XL",
            modelSize: 6_500_000_000
        )

        // Then - Should have two notifications total
        let expectedTotalCount: Int = 2
        #expect(mockNotificationCenter.addedRequests.count == expectedTotalCount)
        let secondNotification: UNNotificationRequest? = mockNotificationCenter.addedRequests.last
        #expect(secondNotification?.content.title == "Stable Diffusion XL Downloaded")
        #expect(secondNotification?.content.body == "Your 6.05 GB model is ready to use!")
    }

    @Test("Notification includes model name and size")
    func testNotificationContent() async {
        // Given
        let mockNotificationCenter: MockNotificationCenter = MockNotificationCenter()
        let notificationManager: DownloadNotificationManager = DownloadNotificationManager(
            notificationCenter: mockNotificationCenter
        )

        // When
        await notificationManager.scheduleModelCompletionNotification(
            modelName: "Llama 3.2",
            modelSize: 4_500_000_000 // 4.5GB
        )

        // Then
        let expectedNotificationCount: Int = 1
        #expect(mockNotificationCenter.addedRequests.count == expectedNotificationCount)
        let notification: UNNotificationRequest? = mockNotificationCenter.addedRequests.first
        #expect(notification?.content.title == "Llama 3.2 Downloaded")
        #expect(notification?.content.body == "Your 4.19 GB model is ready to use!")
    }
}

// MARK: - Mock URLSessionDownloadTask

private class MockDownloadTask: URLSessionDownloadTask, @unchecked Sendable {
    private let _taskIdentifier: Int
    private var _response: URLResponse?

    init(taskIdentifier: Int) {
        self._taskIdentifier = taskIdentifier
        super.init()
    }

    override var taskIdentifier: Int {
        _taskIdentifier
    }

    override var response: URLResponse? {
        get { _response }
        set { _response = newValue }
    }

    deinit {
        // No cleanup required
    }
}
