import Foundation
import SwiftData
import OSLog
import Abstractions

// MARK: - Chat Context Commands
extension ChatCommands {
    public struct FetchContextData: ReadCommand {
        public typealias Result = ContextConfiguration

        private let chatId: UUID

        public init(chatId: UUID) {
            self.chatId = chatId
            Logger.database.info("ChatCommands.FetchContextData initialized with chatId: \(chatId)")
        }

        public func execute(
            in context: ModelContext,
            userId: PersistentIdentifier?,
            rag: Ragging?
        ) throws -> ContextConfiguration {
            Logger.database.info("ChatCommands.FetchContextData.execute started for chat: \(chatId)")

            let chat = try ChatCommands.Read(chatId: chatId).execute(in: context, userId: userId, rag: rag)

            // Get system instruction and maxPrompt from chat's language model configuration
            let systemInstruction = chat.languageModelConfig.systemInstruction.rawValue
            let maxPrompt = chat.languageModelConfig.maxPrompt

            // Convert messages to MessageData
            let contextMessages = chat.messages.map { message in
                // Extract channels for context (commentary and final only)
                let messageChannels: [MessageChannel] = {
                    guard let channels = message.channels else { return [] }
                    
                    return channels
                        .filter { channel in
                            switch channel.type {
                            case .commentary, .final:
                                return true
                            case .analysis, .tool:
                                return false // Exclude from context
                            }
                        }
                        .sorted { $0.order < $1.order }
                        .compactMap { channel -> MessageChannel? in
                            guard !channel.content.isEmpty else { return nil }
                            
                            let channelType: MessageChannel.ChannelType
                            switch channel.type {
                            case .commentary:
                                channelType = .commentary
                            case .final:
                                channelType = .final
                            case .analysis, .tool:
                                return nil // Already filtered above, but be explicit
                            }
                            
                            return MessageChannel(
                                type: channelType,
                                content: channel.content,
                                order: channel.order,
                                associatedToolId: channel.associatedToolId
                            )
                        }
                }()
                
                // Extract tool calls from tool channels, preserving order
                let toolCalls: [ToolCall] = {
                    guard let channels = message.channels else { return [] }
                    
                    return channels
                        .filter { $0.type == .tool }
                        .sorted { $0.order < $1.order }  // Same ordering as assistant response
                        .compactMap { channel -> ToolCall? in
                            guard let toolExecution = channel.toolExecution else { return nil }
                            
                            // Parse the stored ToolRequest JSON
                            let requestJSON = toolExecution.requestJSON
                            guard let requestData = requestJSON.data(using: .utf8),
                                  let request = try? JSONDecoder().decode(ToolRequest.self, from: requestData) else {
                                Logger.database.warning("Failed to decode ToolRequest from JSON: \(toolExecution.requestJSON)")
                                return nil
                            }
                            
                            return ToolCall(
                                name: request.name,
                                arguments: request.arguments,
                                id: request.id.uuidString
                            )
                        }
                }()
                
                return MessageData(
                    id: message.id,
                    createdAt: message.createdAt,
                    userInput: message.userInput,
                    channels: messageChannels,
                    toolCalls: toolCalls
                )
            }

            let config = ContextConfiguration(
                systemInstruction: systemInstruction,
                contextMessages: contextMessages,
                maxPrompt: maxPrompt,
                reasoningLevel: chat.languageModelConfig.reasoningLevel,
                includeCurrentDate: chat.languageModelConfig.includeCurrentDate ?? true,
                knowledgeCutoffDate: chat.languageModelConfig.knowledgeCutoffDate,
                currentDateOverride: chat.languageModelConfig.currentDateOverride
            )

            Logger.database.info("ChatCommands.FetchContextData.execute completed")
            return config
        }
    }

    public struct FetchTableName: ReadCommand {
        public typealias Result = String

        private let chatId: UUID

        public init(chatId: UUID) {
            self.chatId = chatId
            Logger.database.info("ChatCommands.FetchTableName initialized with chatId: \(chatId)")
        }

        public func execute(
            in context: ModelContext,
            userId: PersistentIdentifier?,
            rag: Ragging?
        ) throws -> String {
            Logger.database.info("ChatCommands.FetchTableName.execute started for chat: \(chatId)")

            let chat = try ChatCommands.Read(chatId: chatId).execute(in: context, userId: userId, rag: rag)

            // Use the chat's generateTableName method for consistency
            let tableName = chat.generateTableName()

            Logger.database.info("ChatCommands.FetchTableName.execute completed - table name: \(tableName)")
            return tableName
        }
    }
}
