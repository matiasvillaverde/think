import Foundation

internal enum UIComponentsNotificationNames {}

extension Notification.Name {
    static let remoteAPIKeysDidChange: Notification.Name =
        Notification.Name("remoteAPIKeysDidChange")
}
