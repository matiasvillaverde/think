import Foundation
import SwiftData

// **MARK: - Notification**

@Model
@DebugDescription
public final class NotificationAlert: Identifiable, Equatable, ObservableObject {
    // **MARK: - Identity**

    /// A unique identifier for the entity.
    @Attribute(.unique)
    public private(set) var id: UUID = UUID()

    /// The creation date of the entity.
    @Attribute()
    public private(set) var createdAt: Date = Date()

    @Attribute()
    public internal(set) var type: NotificationType

    @Attribute()
    public internal(set) var localizedMessage: String

    /// Indicates whether the notification has been read by the user.
    @Attribute()
    public internal(set) var isRead: Bool = false

    // **MARK: - Initializer**

    /// Creates a new notification instance.
    /// - Parameters:
    ///   - type: The type of notification (error, success, warning, information).
    ///   - message: The localized message to display to the user.
    public init(
        type: NotificationType,
        message: String
    ) {
        self.type = type
        self.localizedMessage = message
    }

    // **MARK: - Equatable**

    public static func == (lhs: NotificationAlert, rhs: NotificationAlert) -> Bool {
        lhs.id == rhs.id
    }
}

public enum NotificationType: Codable, Equatable, Hashable, Sendable {
    case error
    case success
    case warning
    case information
}

#if DEBUG

// **MARK: - Previews**

extension NotificationAlert {
    @MainActor public static let previewError: NotificationAlert = {
        NotificationAlert(
            type: .error,
            message: "Failed to connect to server"
        )
    }()

    @MainActor public static let previewSuccess: NotificationAlert = {
        NotificationAlert(
            type: .success,
            message: "Message sent successfully"
        )
    }()

    @MainActor public static let previewWarning: NotificationAlert = {
        NotificationAlert(
            type: .warning,
            message: "Low battery warning"
        )
    }()

    @MainActor public static let previewInformation: NotificationAlert = {
        NotificationAlert(
            type: .information,
            message: "New update available"
        )
    }()

    @MainActor public static var previewArray: [NotificationAlert] {
        [previewError, previewSuccess, previewWarning, previewInformation]
    }
}
#endif
