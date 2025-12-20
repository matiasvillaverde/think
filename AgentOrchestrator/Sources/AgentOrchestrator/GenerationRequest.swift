import Abstractions
import Foundation

internal struct GenerationRequest {
    internal let messageId: UUID
    internal let chatId: UUID
    internal let model: SendableModel
    internal let action: Action
    internal let prompt: String

    // Optional configuration
    internal let maxIterations: Int

    internal init(
        messageId: UUID,
        chatId: UUID,
        model: SendableModel,
        action: Action,
        prompt: String,
        maxIterations: Int = 10
    ) {
        self.messageId = messageId
        self.chatId = chatId
        self.model = model
        self.action = action
        self.prompt = prompt
        self.maxIterations = maxIterations
    }
}
