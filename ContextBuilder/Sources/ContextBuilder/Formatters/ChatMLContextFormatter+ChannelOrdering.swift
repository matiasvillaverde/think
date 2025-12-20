import Abstractions
import Foundation

/// Extension for ChatML formatter with complex channel ordering logic
extension ChatMLContextFormatter {
    /// Ordered item for complex channel/tool sequencing
    internal enum OrderedItem {
        case channel(MessageChannel)
        case toolCall(ToolCall)

        var order: Int {
            switch self {
            case let .channel(channel):
                return channel.order

            case .toolCall:
                return Int.max // Tools come after their associated commentary
            }
        }
    }

    /// Creates ordered sequence of channels and tool calls
    internal func createOrderedItems(from messageData: MessageData) -> [OrderedItem] {
        var items: [OrderedItem] = []

        // Add all channels
        items.append(contentsOf: messageData.channels.map { .channel($0) })

        // Add tool calls
        items.append(contentsOf: messageData.toolCalls.map { .toolCall($0) })

        // Sort with special handling for tool-associated commentary
        return items.sorted { lhs, rhs in
            switch (lhs, rhs) {
            case let (.channel(lChannel), .channel(rChannel)):
                return lChannel.order < rChannel.order

            case let (.channel(channel), .toolCall(toolCall)):
                // Commentary for this tool should come before the tool call
                if let toolCallId = toolCall.id,
                    let toolId = UUID(uuidString: toolCallId),
                    channel.associatedToolId == toolId {
                    return true
                }
                return channel.order < Int.max

            case let (.toolCall(toolCall), .channel(channel)):
                // Commentary for this tool should come before the tool call  
                if let toolCallId = toolCall.id,
                    let toolId = UUID(uuidString: toolCallId),
                    channel.associatedToolId == toolId {
                    return false
                }
                return Int.max >= channel.order

            case (.toolCall, .toolCall):
                return false // Maintain original tool call order
            }
        }
    }

    /// Formats message with complex ordering logic
    internal func formatWithOrderedItems(_ messageData: MessageData) -> String {
        var components: [String] = []
        let orderedItems: [OrderedItem] = createOrderedItems(from: messageData)
        // Pre-allocate based on item count  
        let itemPartsCount: Int = 6
        components.reserveCapacity(orderedItems.count * itemPartsCount)

        for item in orderedItems {
            switch item {
            case let .channel(channel):
                switch channel.type {
                case .commentary:
                    components.append(labels.commentaryStartLabel)
                    components.append("\n")
                    components.append(channel.content)
                    components.append("\n")
                    components.append(labels.commentaryEndLabel)
                    components.append("\n")

                case .final:
                    components.append(channel.content)
                    components.append("\n")
                }

            case let .toolCall(toolCall):
                components.append("\n<tool_call>\n")
                components.append(
                    "{\"name\": \"\(toolCall.name)\", \"arguments\": \(toolCall.arguments)}"
                )
                components.append("\n</tool_call>")
            }
        }

        return components.joined()
    }
}
