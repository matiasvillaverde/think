import Abstractions
import Foundation

/// Extension for Harmony formatter with channel-based formatting
extension HarmonyContextFormatter {
    // Constants for channel formatting
    private enum ChannelConstants {
        static let partsPerChannel: Int = 3
    }

    /// Formats assistant message from channels
    internal func formatAssistantMessageFromChannels(
        _ messageData: MessageData,
        isLast: Bool
    ) -> String {
        guard !messageData.channels.isEmpty else {
            return ""
        }

        var components: [String] = []
        let sortedChannels: [MessageChannel] = messageData.channels.sorted { $0.order < $1.order }
        // Pre-allocate for channel components
        components.reserveCapacity(sortedChannels.count * ChannelConstants.partsPerChannel)

        for channel in sortedChannels {
            components.append("<|start|>assistant")

            switch channel.type {
            case .commentary:
                components.append("<|channel|>commentary<|message|>")
                components.append(channel.content)

            case .final:
                components.append("<|channel|>final<|message|>")
                components.append(channel.content)
            }

            if isLast, channel == sortedChannels.last {
                components.append("<|return|>")
            } else {
                components.append("<|return|>")
            }
        }

        return components.joined()
    }

    internal func formatAssistantResponse(_ content: String) -> String {
        formatAssistantResponse(content, isLast: false)
    }

    internal func formatAssistantResponse(_ content: String, isLast: Bool) -> String {
        // For history, we typically just show the final response without channels
        var message: String = "<|start|>assistant<|channel|>final<|message|>\(content)"
        if isLast {
            message += "<|return|>"
        } else {
            message += "<|return|>"
        }
        return message
    }
}
