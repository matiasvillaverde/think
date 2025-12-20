import Foundation

/// Error types for database operations
public enum DatabaseError: LocalizedError, Equatable {
    case databaseNotReady
    case notificationNotFound
    case modelNotFound
    case cannotCreateFirstChat
    case chatNotFound
    case personalityNotFound
    case messageNotFound
    case channelNotFound
    case configurationNotFound
    case fileNotFound
    case userNotFound
    case messageCreationFailed
    case fileCreationFailed
    case toolExecutionNotFound
    case invalidToolExecutionState
    case fetchFailed(NSError)
    case ragRequired
    case timeout
    case invalidInput(String)
    case invalidStateTransition
    case unknown

    public var errorDescription: String? {
        switch self {
        case .cannotCreateFirstChat:
            return "Cannot create first chat"
        case .notificationNotFound:
            return "Notification not found"
        case .databaseNotReady:
            return "Database is not ready"
        case .modelNotFound:
            return "Required model not found"
        case .chatNotFound:
            return "Chat not found"
        case .messageNotFound:
            return "Message not found"
        case .channelNotFound:
            return "Channel not found"
        case .invalidInput(let message):
            return "Invalid input: \(message)"
        case .fileNotFound:
            return "File not found"
        case .configurationNotFound:
            return "Configuration not found"
        case .userNotFound:
            return "User not found"
        case .personalityNotFound:
            return "Personality not found"
        case .messageCreationFailed:
            return "Failed to create message"
        case .fileCreationFailed:
            return "Failed to create file"
        case .toolExecutionNotFound:
            return "Tool execution not found"
        case .invalidToolExecutionState:
            return "Invalid tool execution state"
        case .fetchFailed(let error):
            return "Fetch operation failed: \(error.localizedDescription)"
        case .ragRequired:
            return "RAG is required for this operation"
        case .timeout:
            return "Timeout"
        case .invalidStateTransition:
            return "Invalid state transition, you can't set ready twice"
        case .unknown:
            return "Unknown error"
        }
    }
}
