import Foundation
@preconcurrency import UserNotifications

/// Simplified notification settings for protocol abstraction
internal struct NotificationSettings: Sendable {
    internal let authorizationStatus: UNAuthorizationStatus

    internal init(authorizationStatus: UNAuthorizationStatus) {
        self.authorizationStatus = authorizationStatus
    }

    internal init(from unSettings: UNNotificationSettings) {
        self.authorizationStatus = unSettings.authorizationStatus
    }
}

/// Protocol for notification center operations to enable testing
internal protocol NotificationCenterProtocol: Sendable {
    /// Request authorization for notifications
    func requestAuthorization(options: UNAuthorizationOptions) async throws -> Bool

    /// Get current notification settings
    func notificationSettings() async -> NotificationSettings

    /// Add a notification request
    func add(_ request: UNNotificationRequest) async throws

    /// Remove pending notification requests
    func removePendingNotificationRequests(withIdentifiers identifiers: [String])

    /// Remove delivered notifications  
    func removeDeliveredNotifications(withIdentifiers identifiers: [String])

    /// Get pending notification requests
    func pendingNotificationRequests() async -> [UNNotificationRequest]

    /// Get delivered notifications
    func deliveredNotifications() async -> [UNNotification]
}

/// Real implementation that wraps UNUserNotificationCenter
internal struct RealNotificationCenter: NotificationCenterProtocol {
    private let notificationCenter: UNUserNotificationCenter?

    internal init() {
        // Try to get the notification center, but handle the case where it's not available (e.g., in tests)
        // Check if we're in a test environment first to avoid the crash
        if ProcessInfo.processInfo.environment["XCTestConfigurationFilePath"] != nil ||
           ProcessInfo.processInfo.environment["XCTestBundlePath"] != nil ||
           ProcessInfo.processInfo.arguments.contains("XCTRunner") ||
           // Check for Swift Package Manager test environment
           ProcessInfo.processInfo.environment["SWIFT_PACKAGE_TEST_PRODUCT"] != nil ||
           Bundle.main.bundleURL.path.contains("swift/pm") {
            self.notificationCenter = nil
        } else {
            self.notificationCenter = UNUserNotificationCenter.current()
        }
    }

    internal func requestAuthorization(options: UNAuthorizationOptions) async throws -> Bool {
        guard let notificationCenter else { return false }
        return try await notificationCenter.requestAuthorization(options: options)
    }

    internal func notificationSettings() async -> NotificationSettings {
        guard let notificationCenter else {
            return NotificationSettings(authorizationStatus: .notDetermined)
        }
        let settings: UNNotificationSettings = await notificationCenter.notificationSettings()
        return NotificationSettings(from: settings)
    }

    internal func add(_ request: UNNotificationRequest) async throws {
        guard let notificationCenter else { return }
        try await notificationCenter.add(request)
    }

    internal func removePendingNotificationRequests(withIdentifiers identifiers: [String]) {
        notificationCenter?.removePendingNotificationRequests(withIdentifiers: identifiers)
    }

    internal func removeDeliveredNotifications(withIdentifiers identifiers: [String]) {
        notificationCenter?.removeDeliveredNotifications(withIdentifiers: identifiers)
    }

    internal func pendingNotificationRequests() async -> [UNNotificationRequest] {
        guard let notificationCenter else { return [] }
        return await notificationCenter.pendingNotificationRequests()
    }

    internal func deliveredNotifications() async -> [UNNotification] {
        guard let notificationCenter else { return [] }
        return await notificationCenter.deliveredNotifications()
    }
}

/// Mock implementation for testing
internal final class MockNotificationCenter: NotificationCenterProtocol, @unchecked Sendable {
    internal var authorizationGranted: Bool = true
    internal var authorizationStatus: UNAuthorizationStatus = UNAuthorizationStatus.authorized
    internal var addedRequests: [UNNotificationRequest] = []
    internal var removedPendingIdentifiers: [String] = []
    internal var removedDeliveredIdentifiers: [String] = []

    internal func requestAuthorization(options _: UNAuthorizationOptions) throws -> Bool {
        authorizationGranted
    }

    internal func notificationSettings() -> NotificationSettings {
        NotificationSettings(authorizationStatus: authorizationStatus)
    }

    internal func add(_ request: UNNotificationRequest) throws {
        addedRequests.append(request)
    }

    internal func removePendingNotificationRequests(withIdentifiers identifiers: [String]) {
        removedPendingIdentifiers.append(contentsOf: identifiers)
    }

    internal func removeDeliveredNotifications(withIdentifiers identifiers: [String]) {
        removedDeliveredIdentifiers.append(contentsOf: identifiers)
    }

    internal func pendingNotificationRequests() -> [UNNotificationRequest] {
        addedRequests.filter { request in
            !removedPendingIdentifiers.contains(request.identifier)
        }
    }

    internal func deliveredNotifications() -> [UNNotification] {
        // Return empty for mock - could be enhanced if needed
        []
    }

    // Helper methods for testing
    internal func reset() {
        addedRequests.removeAll()
        removedPendingIdentifiers.removeAll()
        removedDeliveredIdentifiers.removeAll()
        authorizationGranted = true
        authorizationStatus = .authorized
    }

    deinit {
        // No cleanup required
    }
}
