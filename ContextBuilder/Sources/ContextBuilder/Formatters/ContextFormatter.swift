import Abstractions
import Foundation

/// Protocol for context formatters using Strategy pattern
internal protocol ContextFormatter {
    /// Build a context string from build context
    func build(context: BuildContext) -> String
}
