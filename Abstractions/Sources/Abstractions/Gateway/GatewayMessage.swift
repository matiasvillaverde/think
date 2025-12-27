import Foundation

public enum GatewayRole: String, Sendable, Codable, Equatable {
    case user
    case assistant
    case system
    case tool
}

public struct GatewayMessage: Sendable, Equatable, Identifiable, Codable {
    public let id: UUID
    public let role: GatewayRole
    public let content: String
    public let createdAt: Date

    public init(
        id: UUID,
        role: GatewayRole,
        content: String,
        createdAt: Date = Date()
    ) {
        self.id = id
        self.role = role
        self.content = content
        self.createdAt = createdAt
    }
}

public struct GatewaySession: Sendable, Equatable, Identifiable, Codable {
    public let id: UUID
    public let title: String
    public let createdAt: Date
    public let updatedAt: Date

    public init(
        id: UUID,
        title: String,
        createdAt: Date,
        updatedAt: Date
    ) {
        self.id = id
        self.title = title
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }
}

public struct GatewayHistoryOptions: Sendable, Equatable, Codable {
    public let limit: Int

    public init(limit: Int = 50) {
        self.limit = limit
    }
}

public struct GatewaySendOptions: Sendable, Equatable {
    public let action: Action

    public init(action: Action = .textGeneration([])) {
        self.action = action
    }
}

public struct GatewaySendResult: Sendable, Equatable, Codable {
    public let messageId: UUID
    public let assistantMessage: GatewayMessage?

    public init(messageId: UUID, assistantMessage: GatewayMessage?) {
        self.messageId = messageId
        self.assistantMessage = assistantMessage
    }
}
