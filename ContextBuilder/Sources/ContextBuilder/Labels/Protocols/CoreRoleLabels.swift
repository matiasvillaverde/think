import Foundation

/// Core role labels for message participants
internal protocol CoreRoleLabels {
    /// Label for user messages
    var userLabel: String { get }

    /// Label for assistant messages
    var assistantLabel: String { get }

    /// Label for system messages
    var systemLabel: String { get }

    /// Label marking the end of a message
    var endLabel: String { get }
}
