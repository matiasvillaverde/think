import Abstractions
import Foundation
import OSLog
import SwiftData
import SwiftUI

// MARK: - Message Update Commands
extension MessageCommands {
    public struct UpdateProcessedOutput: WriteCommand {
        // MARK: - Properties

        /// Logger for processed output update operations (only for errors)
        private static let logger = Logger(
            subsystem: "Database", category: "MessageCommands")

        private let messageId: UUID
        private let processedOutput: ProcessedOutput
        public var requiresRag: Bool { false }

        // MARK: - Initialization

        public init(messageId: UUID, processedOutput: ProcessedOutput) {
            self.messageId = messageId
            self.processedOutput = processedOutput
        }

        // MARK: - Command Execution

        public func execute(
            in context: ModelContext,
            userId: PersistentIdentifier?,
            rag: Ragging?
        ) throws -> UUID {
            let descriptor = FetchDescriptor<Message>(
                predicate: #Predicate<Message> {
                    $0.id == messageId
                }
            )

            guard let message = try context.fetch(descriptor).first else {
                Self.logger.error("Message not found with ID: \(messageId)")
                throw DatabaseError.messageNotFound
            }

            // Update or create Channel entities from ProcessedOutput channels
            if !processedOutput.channels.isEmpty {
                // Fetch existing channels for this message
                let existingChannels = message.channels ?? []
                var channelsDict: [UUID: Channel] = [:]
                
                // Create a dictionary of existing channels by UUID
                for channel in existingChannels {
                    channelsDict[channel.id] = channel
                }
                
                // Update existing or create new channels for current iteration
                for channelMessage in processedOutput.channels {
                    if let existingChannel = channelsDict[channelMessage.id] {
                        // Update existing channel
                        existingChannel.updateContent(channelMessage.content)
                        existingChannel.recipient = channelMessage.recipient
                        // Mark as complete if this is the final update and content is non-empty
                        if channelMessage.type == .final, !channelMessage.content.isEmpty {
                            existingChannel.markAsComplete()
                        }
                    } else {
                        // Create new channel with UUID from ContextBuilder
                        let newChannel = Channel(
                            id: channelMessage.id,
                            type: Channel.ChannelType(rawValue: channelMessage.type.rawValue) ?? .final,
                            content: channelMessage.content,
                            order: channelMessage.order,
                            recipient: channelMessage.recipient
                        )
                        
                        // Mark as complete if this is the final update and content is non-empty
                        if channelMessage.type == .final, !channelMessage.content.isEmpty {
                            newChannel.markAsComplete()
                        }
                        
                        // Create ToolExecution for tool channels
                        if channelMessage.type == .tool, let toolRequest = channelMessage.toolRequest {
                            let toolExecution = ToolExecution(
                                request: toolRequest,
                                state: .pending,
                                channel: newChannel
                            )
                            newChannel.toolExecution = toolExecution
                            context.insert(toolExecution)
                        }
                        
                        newChannel.message = message
                        context.insert(newChannel)
                        // Add new channel to existing channels list
                        if message.channels == nil {
                            message.channels = [newChannel]
                        } else {
                            message.channels?.append(newChannel)
                        }
                    }
                }
            }

            // Tool requests are now stored as channels with type .tool
            // No separate storage needed

            // Increment version to trigger SwiftData observation
            message.version += 1

            try context.save()
            return message.id
        }
    }

    // UpdateToolResults is temporarily disabled during migration to new ToolExecution model
    // This command will be replaced with ToolExecutionCommands
    /*
    public struct UpdateToolResults: WriteCommand {
        // Implementation removed - migrating to ToolExecution model
    }
    */
    
    // Temporary command for ToolResponse until ToolExecution is fully implemented
    public struct UpdateToolResponses: WriteCommand {
        public typealias Result = UUID
        
        public let messageId: UUID
        public let toolResponses: [ToolResponse]
        public var requiresRag: Bool { false }
        
        public init(messageId: UUID, toolResponses: [ToolResponse]) {
            self.messageId = messageId
            self.toolResponses = toolResponses
        }
        
        public func execute(
            in context: ModelContext,
            userId: PersistentIdentifier?,
            rag: Ragging?
        ) throws -> UUID {
            // Find the message and its tool executions
            let messageDescriptor = FetchDescriptor<Message>(
                predicate: #Predicate<Message> { $0.id == messageId }
            )
            
            guard let message = try context.fetch(messageDescriptor).first else {
                throw DatabaseError.messageNotFound
            }
            
            // Get tool executions from the message's channels
            let toolExecutions = message.channels?.compactMap { $0.toolExecution } ?? []
            
            // Update each tool execution with its corresponding response
            for toolResponse in toolResponses {
                // Find the tool execution that matches this response
                if let execution = toolExecutions.first(where: { execution in
                    execution.request?.name == toolResponse.toolName
                }) {
                    // Transition to executing state if still pending
                    if execution.state == .pending {
                        try execution.transitionTo(.executing)
                    }
                    // Complete the execution with the response
                    try execution.complete(with: toolResponse)
                }
            }
            
            try context.save()
            return messageId
        }
    }
}
