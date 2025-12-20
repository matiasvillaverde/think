import Foundation

/// Configuration options for background downloads
public struct BackgroundDownloadOptions: Sendable, Codable {
    /// Whether to allow downloads over cellular networks
    public let enableCellular: Bool

    /// Custom title for completion notification (nil uses default)
    public let notificationTitle: String?

    /// Custom subtitle for completion notification (nil uses default)
    public let notificationSubtitle: String?

    /// Download priority level
    public let priority: BackgroundDownloadPriority

    /// Whether download should be discretionary (system can delay for optimal conditions)
    public let isDiscretionary: Bool

    public init(
        enableCellular: Bool = false,
        notificationTitle: String? = nil,
        notificationSubtitle: String? = nil,
        priority: BackgroundDownloadPriority = .normal,
        isDiscretionary: Bool = true
    ) {
        self.enableCellular = enableCellular
        self.notificationTitle = notificationTitle
        self.notificationSubtitle = notificationSubtitle
        self.priority = priority
        self.isDiscretionary = isDiscretionary
    }

    /// Default options for background downloads
    public static let `default` = BackgroundDownloadOptions()
}
