import Database

// MARK: - Message Input Validator

/// Validator for message input functionality
public enum MessageInputValidator {
    /// Determines if a message can be sent based on current state
    /// - Parameters:
    ///   - message: The message text to be sent
    ///   - chat: The chat the message will be sent to
    /// - Returns: Boolean indicating if message can be sent
    @MainActor
    static func canSend(message: String, chat: Chat) -> Bool {
        // If the files are not processed, it should not be able to send.
        // This needs to be implemented based on file processing status

        guard !message.isEmpty else {
            return false
        }
        // Check runtime state for readiness
        guard chat.languageModel.runtimeState == .loaded else {
            return false
        }
        guard chat.messages.last != nil else {
            return true
        }

        if chat.languageModel.state?.isDownloading == true {
            return false
        }

        return true
    }

    @MainActor
    static func canStop(chat: Chat) -> Bool {
        chat.languageModel.runtimeState == .generating ||
            chat.imageModel.runtimeState == .generating
    }

    /// Determines if the input field should be disabled
    /// - Parameter chat: The chat to check state against
    /// - Returns: Boolean indicating if input should be disabled
    static func isDisabled(chat: Chat) -> Bool {
        if chat.languageModel.state?.isDownloading == true {
            return true
        }

        return false
    }
}
