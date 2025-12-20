import Foundation

/// Optional commands for controlling thinking mode
internal protocol ThinkingCommandLabels {
    /// Command to enable thinking mode
    var thinkCommand: String? { get }

    /// Command to disable thinking mode
    var noThinkCommand: String? { get }
}
