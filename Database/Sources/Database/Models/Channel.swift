import Foundation
import SwiftData

/// Represents a channel message as a SwiftData entity
@Model
public final class Channel: Identifiable {
    /// The type of channel
    public enum ChannelType: String, Codable, Sendable, Equatable, CaseIterable {
        case analysis
        case commentary
        case final
        case tool
    }
    
    // MARK: - Properties
    
    /// Unique identifier for the channel
    @Attribute(.unique)
    public private(set) var id: UUID
    
    /// The type of channel (analysis, commentary, final)
    @Attribute()
    public var type: ChannelType
    
    /// The content of the channel message
    @Attribute()
    public var content: String
    
    /// The order of this channel in the sequence
    @Attribute()
    public var order: Int
    
    /// Optional recipient (e.g., "functions.toolname" or "user")
    @Attribute()
    public var recipient: String?
    
    /// Optional associated tool ID for linking commentary to tools
    @Attribute()
    public var associatedToolId: UUID?
    
    /// Tool execution for tool channels
    @Relationship
    public var toolExecution: ToolExecution?
    
    /// Indicates if the channel content is complete (for streaming)
    @Attribute()
    public var isComplete: Bool
    
    /// Timestamp of last update (for streaming optimization)
    @Attribute()
    public private(set) var lastUpdated: Date
    
    /// Relationship to the parent Message
    @Relationship
    public var message: Message?
    
    // MARK: - Initialization
    
    /// Initialize a new Channel
    public init(
        id: UUID = UUID(),
        type: ChannelType,
        content: String,
        order: Int,
        recipient: String? = nil,
        associatedToolId: UUID? = nil,
        toolExecution: ToolExecution? = nil,
        isComplete: Bool = false
    ) {
        self.id = id
        self.type = type
        self.content = content
        self.order = order
        self.recipient = recipient
        self.associatedToolId = associatedToolId
        self.toolExecution = toolExecution
        self.isComplete = isComplete
        self.lastUpdated = Date()
    }
    
    /// Convenience initializer with all properties
    public convenience init(
        type: ChannelType,
        content: String,
        order: Int,
        recipient: String? = nil,
        associatedToolId: UUID? = nil,
        toolExecution: ToolExecution? = nil
    ) {
        self.init(
            type: type,
            content: content,
            order: order,
            recipient: recipient,
            associatedToolId: associatedToolId,
            toolExecution: toolExecution,
            isComplete: false  // New channels start as incomplete
        )
    }
    
    // MARK: - Methods
    
    /// Update the content and refresh the lastUpdated timestamp
    public func updateContent(_ newContent: String) {
        guard self.content != newContent else { return } // Skip if identical
        self.content = newContent
        self.lastUpdated = Date()
    }
    
    /// Mark the channel as complete
    public func markAsComplete() {
        self.isComplete = true
        self.lastUpdated = Date()
    }
}

// MARK: - Equatable

extension Channel: Equatable {
    public static func == (lhs: Channel, rhs: Channel) -> Bool {
        lhs.id == rhs.id
    }
}

// MARK: - Hashable

extension Channel: Hashable {
    public func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }
}
