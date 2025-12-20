import Abstractions
import Foundation

/// Protocol for formatters that format messages
internal protocol MessageFormatting {
    func formatSystemMessage(_ content: String, date: Date) -> String
    func formatSystemMessage(_ content: String, date: Date, knowledgeCutoff: String?) -> String
    func formatUserMessage(_ content: String) -> String
    func formatAssistantMessage(_ content: String) -> String
    func formatAssistantMessageFromChannels(_ messageData: MessageData) throws -> String
    func formatToolResponses(_ responses: [ToolResponse]) -> String
}

// Default implementation for formatters that don't need knowledge cutoff customization
extension MessageFormatting {
    func formatSystemMessage(_ content: String, date: Date, knowledgeCutoff _: String?) -> String {
        formatSystemMessage(content, date: date)
    }
}
