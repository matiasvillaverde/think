import Abstractions
import Foundation

/// Protocol for output parsers using Strategy pattern
internal protocol OutputParser {
    /// Parse LLM output into ProcessedOutput
    func parse(_ output: String) async throws -> [ChannelMessage]
}
