import Foundation
import SwiftData
import Abstractions
import OSLog

/// Commands for Channel entity operations
public enum ChannelCommands {
    private static let logger = Logger(subsystem: "Database", category: "ChannelCommands")
    
    // MARK: - Input Types
    
    /// Input for creating or updating a channel
    public struct ChannelInput: Sendable {
        public let type: Channel.ChannelType
        public let content: String
        public let order: Int
        public let recipient: String?
        public let associatedToolId: UUID?
        public let toolExecutionId: UUID?
        public let isComplete: Bool
        
        public init(
            type: Channel.ChannelType,
            content: String,
            order: Int,
            recipient: String? = nil,
            associatedToolId: UUID? = nil,
            toolExecutionId: UUID? = nil,
            isComplete: Bool = false
        ) {
            self.type = type
            self.content = content
            self.order = order
            self.recipient = recipient
            self.associatedToolId = associatedToolId
            self.toolExecutionId = toolExecutionId
            self.isComplete = isComplete
        }
    }
    
    // MARK: - Create Command
    
    public struct Create: WriteCommand {
        private let messageId: UUID
        private let type: Channel.ChannelType
        private let content: String
        private let order: Int
        private let recipient: String?
        private let associatedToolId: UUID?
        private let toolExecutionId: UUID?
        private let isComplete: Bool
        
        public init(
            messageId: UUID,
            type: Channel.ChannelType,
            content: String,
            order: Int,
            recipient: String? = nil,
            associatedToolId: UUID? = nil,
            toolExecutionId: UUID? = nil,
            isComplete: Bool = false
        ) {
            self.messageId = messageId
            self.type = type
            self.content = content
            self.order = order
            self.recipient = recipient
            self.associatedToolId = associatedToolId
            self.toolExecutionId = toolExecutionId
            self.isComplete = isComplete
        }
        
        public func execute(in context: ModelContext, userId: PersistentIdentifier?, rag: (any Ragging)?) throws -> UUID {
            ChannelCommands.logger.debug("Creating channel for message: \(self.messageId)")
            
            // Find the message
            let descriptor = FetchDescriptor<Message>(
                predicate: #Predicate<Message> { $0.id == messageId }
            )
            
            guard let message = try context.fetch(descriptor).first else {
                ChannelCommands.logger.error("Message not found: \(self.messageId)")
                throw DatabaseError.messageNotFound
            }
            
            // Find tool execution if provided
            var toolExecution: ToolExecution?
            if let toolExecutionId = self.toolExecutionId {
                let toolExecutionDescriptor = FetchDescriptor<ToolExecution>(
                    predicate: #Predicate<ToolExecution> { $0.id == toolExecutionId }
                )
                toolExecution = try context.fetch(toolExecutionDescriptor).first
                // Note: We don't throw if not found, just leave it nil
            }
            
            // Create the channel
            let channel = Channel(
                type: type,
                content: content,
                order: order,
                recipient: recipient,
                associatedToolId: associatedToolId,
                toolExecution: toolExecution,
                isComplete: isComplete
            )
            
            // Set relationship
            channel.message = message
            context.insert(channel)
            
            // Save is handled by Database wrapper
            
            ChannelCommands.logger.debug("Channel created with ID: \(channel.id)")
            return channel.id
        }
    }
    
    // MARK: - Update Command
    
    public struct Update: WriteCommand {
        private let channelId: UUID
        private let content: String
        private let markComplete: Bool
        
        public init(
            channelId: UUID,
            content: String,
            markComplete: Bool = false
        ) {
            self.channelId = channelId
            self.content = content
            self.markComplete = markComplete
        }
        
        public func execute(in context: ModelContext, userId: PersistentIdentifier?, rag: (any Ragging)?) throws -> UUID {
            ChannelCommands.logger.debug("Updating channel: \(self.channelId)")
            
            // Find the channel
            let descriptor = FetchDescriptor<Channel>(
                predicate: #Predicate<Channel> { $0.id == channelId }
            )
            
            guard let channel = try context.fetch(descriptor).first else {
                ChannelCommands.logger.error("Channel not found: \(self.channelId)")
                throw DatabaseError.channelNotFound
            }
            
            // Update the channel
            channel.updateContent(content)
            
            if markComplete {
                channel.markAsComplete()
            }
            
            // Save is handled by Database wrapper
            
            ChannelCommands.logger.debug("Channel updated: \(self.channelId)")
            return channel.id
        }
    }
    
    // MARK: - Link Tool Execution Command
    
    public struct LinkToolExecution: WriteCommand {
        private let channelId: UUID
        private let toolExecutionId: UUID
        
        public init(channelId: UUID, toolExecutionId: UUID) {
            self.channelId = channelId
            self.toolExecutionId = toolExecutionId
        }
        
        public func execute(in context: ModelContext, userId: PersistentIdentifier?, rag: (any Ragging)?) throws -> UUID {
            ChannelCommands.logger.debug("Linking tool execution \(self.toolExecutionId) to channel \(self.channelId)")
            
            // Find the channel
            let channelDescriptor = FetchDescriptor<Channel>(
                predicate: #Predicate<Channel> { $0.id == channelId }
            )
            
            guard let channel = try context.fetch(channelDescriptor).first else {
                ChannelCommands.logger.error("Channel not found: \(self.channelId)")
                throw DatabaseError.channelNotFound
            }
            
            // Find the tool execution
            let toolExecutionDescriptor = FetchDescriptor<ToolExecution>(
                predicate: #Predicate<ToolExecution> { $0.id == toolExecutionId }
            )
            
            guard let toolExecution = try context.fetch(toolExecutionDescriptor).first else {
                ChannelCommands.logger.error("Tool execution not found: \(self.toolExecutionId)")
                throw DatabaseError.toolExecutionNotFound
            }
            
            // Link the tool execution to the channel
            channel.toolExecution = toolExecution
            
            // Save is handled by Database wrapper
            
            ChannelCommands.logger.debug("Tool execution linked to channel: \(self.channelId)")
            return channel.id
        }
    }
    
    // MARK: - Batch Upsert Command
    
    public struct BatchUpsert: WriteCommand {
        private let messageId: UUID
        private let channels: [ChannelInput]
        
        public init(messageId: UUID, channels: [ChannelInput]) {
            self.messageId = messageId
            self.channels = channels
        }
        
        public func execute(in context: ModelContext, userId: PersistentIdentifier?, rag: (any Ragging)?) throws -> UUID {
            ChannelCommands.logger.debug("Batch upserting \(self.channels.count) channels for message: \(self.messageId)")
            
            // Find the message
            let messageDescriptor = FetchDescriptor<Message>(
                predicate: #Predicate<Message> { $0.id == messageId }
            )
            
            guard let message = try context.fetch(messageDescriptor).first else {
                ChannelCommands.logger.error("Message not found: \(self.messageId)")
                throw DatabaseError.messageNotFound
            }
            
            var channelIds: [UUID] = []
            
            for channelInput in channels {
                // Check if channel exists (by type and order for this message)
                // We need to fetch all channels for this message and filter in memory
                // due to SwiftData predicate limitations with optionals
                let existingDescriptor = FetchDescriptor<Channel>()
                let allChannels = try context.fetch(existingDescriptor)
                let existingChannel = allChannels.first { channel in
                    channel.message?.id == messageId &&
                    channel.type == channelInput.type &&
                    channel.order == channelInput.order
                }
                
                if let existingChannel = existingChannel {
                    // Update existing channel
                    existingChannel.updateContent(channelInput.content)
                    if channelInput.isComplete {
                        existingChannel.markAsComplete()
                    }
                    existingChannel.recipient = channelInput.recipient
                    existingChannel.associatedToolId = channelInput.associatedToolId
                    
                    // Update tool execution if provided
                    if let toolExecutionId = channelInput.toolExecutionId {
                        let toolExecutionDescriptor = FetchDescriptor<ToolExecution>(
                            predicate: #Predicate<ToolExecution> { $0.id == toolExecutionId }
                        )
                        existingChannel.toolExecution = try context.fetch(toolExecutionDescriptor).first
                    }
                    
                    channelIds.append(existingChannel.id)
                    ChannelCommands.logger.debug("Updated existing channel: \(existingChannel.id)")
                } else {
                    // Find tool execution if provided
                    var toolExecution: ToolExecution?
                    if let toolExecutionId = channelInput.toolExecutionId {
                        let toolExecutionDescriptor = FetchDescriptor<ToolExecution>(
                            predicate: #Predicate<ToolExecution> { $0.id == toolExecutionId }
                        )
                        toolExecution = try context.fetch(toolExecutionDescriptor).first
                    }
                    
                    // Create new channel
                    let newChannel = Channel(
                        type: channelInput.type,
                        content: channelInput.content,
                        order: channelInput.order,
                        recipient: channelInput.recipient,
                        associatedToolId: channelInput.associatedToolId,
                        toolExecution: toolExecution,
                        isComplete: channelInput.isComplete
                    )
                    newChannel.message = message
                    context.insert(newChannel)
                    
                    channelIds.append(newChannel.id)
                    ChannelCommands.logger.debug("Created new channel: \(newChannel.id)")
                }
            }
            
            // Save is handled by Database wrapper
            
            ChannelCommands.logger.debug("Batch upserted \(channelIds.count) channels")
            // Return the message ID as a convention for batch operations
            return messageId
        }
    }
}