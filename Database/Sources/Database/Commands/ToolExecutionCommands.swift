import Abstractions
import Foundation
import SwiftData

// MARK: - Tool Execution Commands

public enum ToolExecutionCommands {}

extension ToolExecutionCommands {
    // MARK: - Create Command
    
    public struct Create: WriteCommand {
        let request: ToolRequest
        let channelId: UUID?
        let messageId: UUID
        
        public init(request: ToolRequest, channelId: UUID?, messageId: UUID) {
            self.request = request
            self.channelId = channelId
            self.messageId = messageId
        }
        
        public func execute(
            in context: ModelContext,
            userId: PersistentIdentifier?,
            rag: Ragging?
        ) throws -> UUID {
            // Find the message first
            let messageFetch = FetchDescriptor<Message>(
                predicate: #Predicate { $0.id == messageId }
            )
            guard let message = try context.fetch(messageFetch).first else {
                throw DatabaseError.messageNotFound
            }
            
            // Find or create channel
            var channel: Channel?
            if let channelId {
                // Use existing channel if provided
                let channelFetch = FetchDescriptor<Channel>(
                    predicate: #Predicate { $0.id == channelId }
                )
                channel = try context.fetch(channelFetch).first
            } else {
                // Create a new tool channel for this execution
                let newChannel = Channel(
                    type: .tool,
                    content: "Tool: \(request.name)",
                    order: (message.channels?.count ?? 0),
                    recipient: request.recipient,
                    associatedToolId: request.id
                )
                newChannel.message = message
                context.insert(newChannel)
                channel = newChannel
            }
            
            // Create ToolExecution entity with channel
            let execution = ToolExecution(
                request: request,
                state: .pending,
                channel: channel
            )
            
            context.insert(execution)
            
            // Update the channel to link to the tool execution
            channel?.toolExecution = execution

            // Persist so fetch-based reads reflect the new execution immediately.
            try context.save()
            
            return execution.id
        }
    }
    
    // MARK: - StartExecution Command
    
    public struct StartExecution: WriteCommand {
        let executionId: UUID
        
        public init(executionId: UUID) {
            self.executionId = executionId
        }
        
        public func execute(
            in context: ModelContext,
            userId: PersistentIdentifier?,
            rag: Ragging?
        ) throws -> UUID {
            let fetch = FetchDescriptor<ToolExecution>(
                predicate: #Predicate { $0.id == executionId }
            )
            
            guard let execution = try context.fetch(fetch).first else {
                throw DatabaseError.toolExecutionNotFound
            }
            
            // Check if already executing or completed
            guard execution.state == .pending else {
                throw DatabaseError.invalidToolExecutionState
            }
            
            try execution.transitionTo(.executing)

            // Persist so UI (and fetch-based reads) observe the state transition.
            try context.save()
            
            return execution.id
        }
    }

    // MARK: - UpdateProgress Command

    public struct UpdateProgress: WriteCommand {
        let executionId: UUID
        let progress: Double?
        let status: String?

        public init(executionId: UUID, progress: Double?, status: String?) {
            self.executionId = executionId
            self.progress = progress
            self.status = status
        }

        public func execute(
            in context: ModelContext,
            userId: PersistentIdentifier?,
            rag: Ragging?
        ) throws -> UUID {
            let fetch = FetchDescriptor<ToolExecution>(
                predicate: #Predicate { $0.id == executionId }
            )

            guard let execution = try context.fetch(fetch).first else {
                throw DatabaseError.toolExecutionNotFound
            }

            execution.updateProgress(progress, status: status)

            // Persist progress/status so observers and fetches see updates.
            try context.save()

            return execution.id
        }
    }
    
    // MARK: - Complete Command
    
    public struct Complete: WriteCommand {
        let executionId: UUID
        let response: ToolResponse
        
        public init(executionId: UUID, response: ToolResponse) {
            self.executionId = executionId
            self.response = response
        }
        
        public func execute(
            in context: ModelContext,
            userId: PersistentIdentifier?,
            rag: Ragging?
        ) throws -> UUID {
            let fetch = FetchDescriptor<ToolExecution>(
                predicate: #Predicate { $0.id == executionId }
            )
            
            guard let execution = try context.fetch(fetch).first else {
                throw DatabaseError.toolExecutionNotFound
            }
            
            try execution.complete(with: response)

            // Persist completion state and response payload.
            try context.save()
            
            return execution.id
        }
    }
    
    // MARK: - Fail Command
    
    public struct Fail: WriteCommand {
        let executionId: UUID
        let error: String
        
        public init(executionId: UUID, error: String) {
            self.executionId = executionId
            self.error = error
        }
        
        public func execute(
            in context: ModelContext,
            userId: PersistentIdentifier?,
            rag: Ragging?
        ) throws -> UUID {
            let fetch = FetchDescriptor<ToolExecution>(
                predicate: #Predicate { $0.id == executionId }
            )
            
            guard let execution = try context.fetch(fetch).first else {
                throw DatabaseError.toolExecutionNotFound
            }
            
            try execution.fail(with: error)

            // Persist failure state and error details.
            try context.save()
            
            return execution.id
        }
    }
    
    // MARK: - Read Commands
    
    public struct Get: ReadCommand {
        let executionId: UUID
        
        public init(executionId: UUID) {
            self.executionId = executionId
        }
        
        public func execute(
            in context: ModelContext,
            userId: PersistentIdentifier?,
            rag: Ragging?
        ) throws -> ToolExecution? {
            let fetch = FetchDescriptor<ToolExecution>(
                predicate: #Predicate { $0.id == executionId }
            )
            
            return try context.fetch(fetch).first
        }
    }
    
    public struct GetByMessage: ReadCommand {
        let messageId: UUID
        
        public init(messageId: UUID) {
            self.messageId = messageId
        }
        
        public func execute(
            in context: ModelContext,
            userId: PersistentIdentifier?,
            rag: Ragging?
        ) throws -> [ToolExecution] {
            let fetch = FetchDescriptor<Message>(
                predicate: #Predicate { $0.id == messageId }
            )
            
            guard let message = try context.fetch(fetch).first else {
                return []
            }
            
            // Get tool executions through channels
            let channels = message.channels ?? []
            let toolExecutions = channels.compactMap { $0.toolExecution }
            return toolExecutions
        }
    }
    
    public struct GetByChannel: ReadCommand {
        let channelId: UUID
        
        public init(channelId: UUID) {
            self.channelId = channelId
        }
        
        public func execute(
            in context: ModelContext,
            userId: PersistentIdentifier?,
            rag: Ragging?
        ) throws -> [ToolExecution] {
            let channelFetch = FetchDescriptor<Channel>(
                predicate: #Predicate { $0.id == channelId }
            )
            
            guard let channel = try context.fetch(channelFetch).first,
                  let execution = channel.toolExecution else {
                return []
            }
            
            return [execution]
        }
    }
    
    public struct GetPending: ReadCommand {
        public init() {}
        
        public func execute(
            in context: ModelContext,
            userId: PersistentIdentifier?,
            rag: Ragging?
        ) throws -> [ToolExecution] {
            // Fetch all and filter in memory due to SwiftData limitations with enum predicates
            let fetch = FetchDescriptor<ToolExecution>()
            let allExecutions = try context.fetch(fetch)
            return allExecutions.filter { $0.state == .pending }
        }
    }
    
    public struct GetExecuting: ReadCommand {
        public init() {}
        
        public func execute(
            in context: ModelContext,
            userId: PersistentIdentifier?,
            rag: Ragging?
        ) throws -> [ToolExecution] {
            // Fetch all and filter in memory due to SwiftData limitations with enum predicates
            let fetch = FetchDescriptor<ToolExecution>()
            let allExecutions = try context.fetch(fetch)
            return allExecutions.filter { $0.state == .executing }
        }
    }
}
