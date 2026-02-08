import Abstractions
import Database
import Foundation

public final actor LocalGatewayService: GatewayServicing {
    private let database: DatabaseProtocol
    private let orchestrator: AgentOrchestrating
    private let subAgentCoordinator: SubAgentOrchestrating?

    public init(
        database: DatabaseProtocol,
        orchestrator: AgentOrchestrating,
        subAgentCoordinator: SubAgentOrchestrating? = nil
    ) {
        self.database = database
        self.orchestrator = orchestrator
        self.subAgentCoordinator = subAgentCoordinator
    }

    public func createSession(title: String?) async throws -> GatewaySession {
        // Create a new personality per session because Personality.chat is a 1:1 relationship.
        // Reusing the default personality would cause subsequent "create session" calls
        // to reuse and clear the same chat.
        let personalityId: UUID = try await database.write(
            PersonalityCommands.CreateSessionPersonality(title: title)
        )
        let chatId: UUID = try await database.write(
            ChatCommands.Create(personality: personalityId)
        )

        if let title, !title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            _ = try await database.write(
                ChatCommands.Rename(chatId: chatId, newName: title)
            )
        }

        return try await database.read(ChatCommands.FetchGatewaySession(chatId: chatId))
    }

    public func listSessions() async throws -> [GatewaySession] {
        let sessions: [GatewaySession] = try await database.read(ChatCommands.FetchGatewaySessions())
        return sessions.sorted { $0.updatedAt > $1.updatedAt }
    }

    public func getSession(id: UUID) async throws -> GatewaySession {
        try await database.read(ChatCommands.FetchGatewaySession(chatId: id))
    }

    public func history(
        sessionId: UUID,
        options: GatewayHistoryOptions
    ) async throws -> [GatewayMessage] {
        let messages: [MessageData] = try await fetchContextMessages(sessionId: sessionId)
        let history: [GatewayMessage] = buildHistory(from: messages)
        if options.limit <= 0 {
            return []
        }
        return Array(history.suffix(options.limit))
    }

    public func send(
        sessionId: UUID,
        input: String,
        options: GatewaySendOptions
    ) async throws -> GatewaySendResult {
        let existingIds: Set<UUID> = try await messageIds(in: sessionId)

        try await orchestrator.load(chatId: sessionId)
        try await orchestrator.generate(prompt: input, action: options.action)

        let messages: [MessageData] = try await fetchContextMessages(sessionId: sessionId)
        guard let message: MessageData = selectNewMessage(
            messages: messages,
            excluding: existingIds,
            input: input
        ) else {
            throw GatewayError.responseNotAvailable
        }

        let assistantMessage: GatewayMessage? = buildAssistantMessage(from: message)
        return GatewaySendResult(messageId: message.id, assistantMessage: assistantMessage)
    }

    public func spawnSubAgent(
        sessionId: UUID,
        request: SubAgentRequest
    ) async throws -> SubAgentResult {
        guard let subAgentCoordinator else {
            throw GatewayError.subAgentUnavailable
        }

        let adaptedRequest: SubAgentRequest = SubAgentRequest(
            parentMessageId: request.parentMessageId,
            parentChatId: sessionId,
            prompt: request.prompt,
            id: request.id,
            tools: request.tools,
            mode: request.mode,
            timeout: request.timeout,
            systemInstruction: request.systemInstruction,
            createdAt: request.createdAt
        )

        _ = await subAgentCoordinator.spawn(request: adaptedRequest)
        return try await subAgentCoordinator.waitForCompletion(requestId: adaptedRequest.id)
    }

    private func buildHistory(from messages: [MessageData]) -> [GatewayMessage] {
        let sortedMessages: [MessageData] = messages.sorted { $0.createdAt < $1.createdAt }
        var history: [GatewayMessage] = []

        for message in sortedMessages {
            if let userInput = message.userInput {
                history.append(
                    GatewayMessage(
                        id: message.id,
                        role: .user,
                        content: userInput,
                        createdAt: message.createdAt
                    )
                )
            }

            if let assistantMessage = buildAssistantMessage(from: message) {
                history.append(assistantMessage)
            }
        }

        return history
    }

    private func buildAssistantMessage(from message: MessageData) -> GatewayMessage? {
        let channel: MessageChannel? = message.channels.last { candidate in
            candidate.type == .final
        }
        guard let channel else {
            return nil
        }
        guard !channel.content.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            return nil
        }

        return GatewayMessage(
            id: message.id,
            role: .assistant,
            content: channel.content,
            createdAt: message.createdAt
        )
    }

    private func selectNewMessage(
        messages: [MessageData],
        excluding existingIds: Set<UUID>,
        input: String
    ) -> MessageData? {
        let sorted: [MessageData] = messages.sorted { $0.createdAt < $1.createdAt }
        let matching: MessageData? = sorted.last { candidate in
            !existingIds.contains(candidate.id) && candidate.userInput == input
        }
        if let matching {
            return matching
        }
        let fallback: MessageData? = sorted.last { candidate in
            !existingIds.contains(candidate.id)
        }
        return fallback ?? sorted.last
    }

    private func messageIds(in sessionId: UUID) async throws -> Set<UUID> {
        let messages: [MessageData] = try await fetchContextMessages(sessionId: sessionId)
        return Set(messages.map(\.id))
    }

    private func fetchContextMessages(sessionId: UUID) async throws -> [MessageData] {
        let config: ContextConfiguration = try await database.read(
            ChatCommands.FetchContextData(chatId: sessionId)
        )
        return config.contextMessages
    }
}
