import Foundation

/// Labels for thinking/reasoning sections
internal protocol ThinkingLabels {
    /// Label marking the start of thinking
    var thinkingStartLabel: String { get }

    /// Label marking the end of thinking
    var thinkingEndLabel: String { get }
}
