import Abstractions
import Foundation
import OSLog
import SwiftData
import SwiftUI

// MARK: - Message Update Commands
extension MessageCommands {
    /// Updates the final channel content for a message without re-processing all channels.
    ///
    /// Intended for high-frequency streaming updates to keep UI smooth and reliable.
    public struct UpdateFinalChannelContent: WriteCommand {
        public typealias Result = UUID

        private static let logger = Logger(
            subsystem: "Database", category: "MessageCommands"
        )

        private let messageId: UUID
        private let content: String
        private let isComplete: Bool
        public var requiresRag: Bool { false }

        public init(messageId: UUID, content: String, isComplete: Bool) {
            self.messageId = messageId
            self.content = content
            self.isComplete = isComplete
        }

        public func execute(
            in context: ModelContext,
            userId: PersistentIdentifier?,
            rag: Ragging?
        ) throws -> UUID {
            let descriptor = FetchDescriptor<Message>(
                predicate: #Predicate<Message> { $0.id == messageId }
            )

            guard let message = try context.fetch(descriptor).first else {
                Self.logger.error("Message not found with ID: \(messageId)")
                throw DatabaseError.messageNotFound
            }

            if let channels = message.channels,
                let finalChannel = channels
                .filter({ $0.type == .final })
                .min(by: { $0.order < $1.order }) {
                finalChannel.updateContent(content)
                if isComplete {
                    if finalChannel.isComplete == false {
                        finalChannel.markAsComplete()
                    }
                } else {
                    finalChannel.isComplete = false
                }
            } else {
                // Fallback: create a final channel if the message was not initialized with channels yet.
                // This should be rare in production; normal streaming initializes channels first.
                let newChannel = Channel(
                    id: UUID(),
                    type: .final,
                    content: content,
                    order: 0,
                    recipient: nil,
                    associatedToolId: nil,
                    toolExecution: nil,
                    isComplete: isComplete
                )
                newChannel.message = message
                context.insert(newChannel)
                if message.channels == nil {
                    message.channels = [newChannel]
                } else {
                    message.channels?.append(newChannel)
                }
            }

            message.version += 1
            try context.save()
            return message.id
        }
    }

    public struct UpdateProcessedOutput: WriteCommand {
        // MARK: - Properties

        /// Logger for processed output update operations (only for errors)
        private static let logger = Logger(
            subsystem: "Database", category: "MessageCommands")

        private let messageId: UUID
        private let processedOutput: ProcessedOutput
        public var requiresRag: Bool { false }

        private struct ChannelIdentityKey: Hashable {
            let type: Channel.ChannelType
            let recipient: String?
            let order: Int
        }

        // MARK: - Initialization

        public init(messageId: UUID, processedOutput: ProcessedOutput) {
            self.messageId = messageId
            self.processedOutput = processedOutput
        }

        // MARK: - Command Execution

        private func identityKey(forExisting channel: Channel) -> ChannelIdentityKey {
            ChannelIdentityKey(
                type: channel.type,
                recipient: channel.recipient,
                order: channel.order
            )
        }

        private func identityKey(forIncoming message: ChannelMessage) -> ChannelIdentityKey {
            ChannelIdentityKey(
                type: Channel.ChannelType(rawValue: message.type.rawValue) ?? .final,
                recipient: message.recipient,
                order: message.order
            )
        }

        private func findStreamingPlaceholderChannel(
            for incoming: ChannelMessage,
            among existing: [Channel]
        ) -> Channel? {
            let incomingType = Channel.ChannelType(rawValue: incoming.type.rawValue) ?? .final
            guard incomingType != .tool else {
                return nil
            }

            let sameType: [Channel] = existing.filter {
                $0.type == incomingType && $0.recipient == incoming.recipient
            }
            guard sameType.contains(where: { $0.order == incoming.order }) == false else {
                return nil
            }

            // Common case: streaming created a single incomplete channel before parsing produced an order.
            // We merge into that single incomplete placeholder to avoid duplicates.
            guard sameType.count == 1, let only = sameType.first, only.isComplete == false else {
                return nil
            }
            return only
        }

        private func indexAndDedupeExistingChannels(
            existingChannels: [Channel],
            context: ModelContext
        ) -> (byId: [UUID: Channel], byIdentity: [ChannelIdentityKey: Channel]) {
            var byId: [UUID: Channel] = [:]
            var byIdentity: [ChannelIdentityKey: Channel] = [:]

            for channel in existingChannels {
                byId[channel.id] = channel
                let key: ChannelIdentityKey = identityKey(forExisting: channel)
                if byIdentity[key] == nil {
                    byIdentity[key] = channel
                } else {
                    let keeper = byIdentity[key]
                    let shouldReplace: Bool = (keeper?.toolExecution == nil) && (channel.toolExecution != nil)
                    if shouldReplace {
                        byIdentity[key] = channel
                    }
                }
            }

            let keepers: Set<UUID> = Set(byIdentity.values.map(\.id))
            for channel in existingChannels where !keepers.contains(channel.id) {
                context.delete(channel)
            }

            return (byId: byId, byIdentity: byIdentity)
        }

        private func applyIncomingChannelMessage(
            _ channelMessage: ChannelMessage,
            to existingChannel: Channel
        ) {
            existingChannel.updateContent(channelMessage.content)
            existingChannel.recipient = channelMessage.recipient
            existingChannel.order = channelMessage.order

            if channelMessage.type == .tool {
                // Preserve the originally associated tool id to keep tool executions stable.
                if existingChannel.associatedToolId == nil {
                    existingChannel.associatedToolId = channelMessage.toolRequest?.id
                }
            }

            if channelMessage.isComplete {
                if existingChannel.isComplete == false {
                    existingChannel.markAsComplete()
                }
            } else {
                existingChannel.isComplete = false
            }
        }

        private func createChannelEntity(
            from channelMessage: ChannelMessage,
            message: Message,
            context: ModelContext
        ) -> Channel {
            let initialContent: String
            var associatedToolId: UUID?
            if channelMessage.type == .tool, let toolRequest = channelMessage.toolRequest {
                // Keep UI-friendly summary in the channel; details live in ToolExecution.
                initialContent = "Tool: \(toolRequest.displayName ?? toolRequest.name)"
                associatedToolId = toolRequest.id
            } else {
                initialContent = channelMessage.content
            }

            let newChannel = Channel(
                // Never persist parser-provided UUIDs. ContextBuilder IDs are only meant to be stable
                // within a single streaming parse, and can collide across messages (the Channel model
                // enforces global uniqueness).
                id: UUID(),
                type: Channel.ChannelType(rawValue: channelMessage.type.rawValue) ?? .final,
                content: initialContent,
                order: channelMessage.order,
                recipient: channelMessage.recipient,
                associatedToolId: associatedToolId,
                toolExecution: nil,
                isComplete: channelMessage.isComplete
            )

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
            if message.channels == nil {
                message.channels = [newChannel]
            } else {
                message.channels?.append(newChannel)
            }

            return newChannel
        }

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
                var (channelsById, channelsByIdentity): ([UUID: Channel], [ChannelIdentityKey: Channel]) =
                    indexAndDedupeExistingChannels(existingChannels: existingChannels, context: context)
                
                // Update existing or create new channels for current iteration
                for channelMessage in processedOutput.channels {
                    let incomingKey: ChannelIdentityKey = identityKey(forIncoming: channelMessage)

                    // Prefer UUID match when possible; otherwise fall back to identity match.
                    let dedupedExisting: [Channel] = Array(channelsByIdentity.values)
                    let existingChannel: Channel? =
                        channelsById[channelMessage.id]
                        ?? channelsByIdentity[incomingKey]
                        ?? findStreamingPlaceholderChannel(for: channelMessage, among: dedupedExisting)

                    if let existingChannel {
                        applyIncomingChannelMessage(channelMessage, to: existingChannel)
                    } else {
                        let newChannel: Channel = createChannelEntity(
                            from: channelMessage,
                            message: message,
                            context: context
                        )

                        channelsById[newChannel.id] = newChannel
                        channelsByIdentity[identityKey(forExisting: newChannel)] = newChannel
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
