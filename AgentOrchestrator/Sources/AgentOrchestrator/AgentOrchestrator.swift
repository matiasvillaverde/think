// swiftlint:disable file_length

import Abstractions
import AsyncAlgorithms
import ContextBuilder
import Database
import Foundation
import OSLog

// swiftlint:disable:next type_body_length
internal final actor AgentOrchestrator: AgentOrchestrating {
    private static let logger: Logger = Logger(
        subsystem: AgentOrchestratorConfiguration.shared.logging.subsystem,
        category: "AgentOrchestrator"
    )

    #if DEBUG
    private static let tokenProcessingLogger: Logger = Logger(
        subsystem: AgentOrchestratorConfiguration.shared.logging.subsystem,
        category: "tokenProcessing"
    )
    #endif

    private let modelCoordinator: ModelStateCoordinator
    private let persistor: MessagePersistor
    private let database: DatabaseProtocol
    private let decisionChain: DecisionHandler
    private let contextBuilder: ContextBuilder
    private let tooling: Tooling?
    private var currentChatId: UUID?

    internal func load(chatId: UUID) async throws {
        try await modelCoordinator.load(chatId: chatId)
        currentChatId = chatId
    }
    internal func unload() async throws {
        try await modelCoordinator.unload()
        currentChatId = nil
    }
    internal func stop() async throws {
        try await modelCoordinator.stop()
    }

    internal func generate(prompt: String, action: Action) async throws {
        guard let chatId = currentChatId else {
            throw ModelStateCoordinatorError.noChatLoaded
        }

        switch action {
        case .textGeneration:
            try await generateTextual(chatId: chatId, prompt: prompt, action: action)

        case .imageGeneration:
            try await generateVisual(chatId: chatId, prompt: prompt)
        }
    }

    private func generateTextual(chatId: UUID, prompt: String, action: Action) async throws {
        let model: SendableModel = try await database.read(
            ChatCommands.GetLanguageModel(chatId: chatId)
        )

        let messageId: UUID = try await persistor.createMessage(
            chatId: chatId,
            prompt: prompt,
            model: model
        )

        let request: GenerationRequest = GenerationRequest(
            messageId: messageId,
            chatId: chatId,
            model: model,
            action: action,
            prompt: prompt
        )

        try await orchestrate(request: request)
    }

    private func generateVisual(chatId: UUID, prompt: String) async throws {
        let imageModel: SendableModel = try await database.read(
            ChatCommands.GetImageModel(chatId: chatId)
        )

        let messageId: UUID = try await persistor.createImageMessage(
            chatId: chatId,
            prompt: prompt,
            model: imageModel
        )

        try await processImageGeneration(
            chatId: chatId,
            messageId: messageId,
            prompt: prompt,
            imageModel: imageModel
        )
    }

    private func processImageGeneration(
        chatId: UUID,
        messageId: UUID,
        prompt: String,
        imageModel: SendableModel
    ) async throws {
        let imageConfig: ImageConfiguration = try await database.read(
            ImageCommands.GetImageConfiguration(chat: chatId, prompt: prompt)
        )

        for try await progress in await modelCoordinator.generate(
            model: imageModel,
            config: imageConfig
        ) {
            if let cgImage = progress.currentImage {
                try await persistor.updateGeneratedImage(
                    messageId: messageId,
                    cgImage: cgImage,
                    configurationId: imageConfig.id,
                    prompt: prompt,
                    imageMetrics: progress.imageMetrics
                )    }
        }
    }

    internal init(
        modelCoordinator: ModelStateCoordinator,
        persistor: MessagePersistor,
        contextBuilder: ContextBuilder,
        tooling: Tooling? = nil
    ) {
        self.modelCoordinator = modelCoordinator
        self.persistor = persistor
        self.database = persistor.database
        self.contextBuilder = contextBuilder
        self.tooling = tooling
        self.decisionChain = buildDecisionChain()
    }

    private func orchestrate(request: GenerationRequest) async throws {
        var state: GenerationState = GenerationState(request: request)
        Self.logger.notice(
            "Starting orchestration for message: \(request.messageId), chat: \(request.chatId)"
        )

        while !state.isComplete {
            Self.logger.info(
                "Orchestration loop iteration \(state.iterationCount + 1) for message: \(state.messageId)"
            )    // Step 1: Stream generation with real-time updates
            state = try await streamGeneration(state)

            // Step 2: Make decision after stream completes
            let decision: GenerationDecision? = try await decisionChain.decide(state)
            Self.logger.info(
                "Decision made: \(String(describing: decision)) for iteration \(state.iterationCount)"
            )

            // Step 3: Execute decision
            state = try await executeDecision(decision ?? .complete, state: state)
        }
        Self.logger.notice(
            "Orchestration completed for message: \(state.messageId) after \(state.iterationCount) iterations"
        )
    }

    private func streamGeneration(_ state: GenerationState) async throws ->
    GenerationState {
        Self.logger.debug("Starting stream generation for iteration \(state.iterationCount)")
        let context: String = try await buildContext(for: state)
        let input: LLMInput = try await buildLLMInput(
            context: context,
            state: state
        )

        let (accumulatedText, metrics): (String, ChunkMetrics?) = try await processStream(
            input: input,
            state: state
        )

        let finalOutput: ProcessedOutput = try await finalizeOutput(
            accumulatedText: accumulatedText,
            state: state
        )

        return state.withStreamComplete(
            output: finalOutput,
            metrics: metrics
        )
    }

    private func buildLLMInput(
        context: String,
        state: GenerationState
    ) async throws -> LLMInput {
        let inputBuilder: LLMInputBuilder = LLMInputBuilder(
            chat: state.chatId,
            model: state.model,
            database: database,
            contextBuilder: contextBuilder
        )
        return try await inputBuilder.build(context: context)
    }

    private func buildContext(for state: GenerationState) async throws -> String {
        let hasToolResults: Bool = !state.toolResults.isEmpty
        Self.logger.debug(
            "Building context for iteration \(state.iterationCount), has tool results: \(hasToolResults)"
        )

        // Configure semantic search if attachments exist
        let modifiedAction: Action = try await configureSemanticSearchIfNeeded(
            for: state.action,
            chatId: state.chatId
        )

        // Fetch context configuration from database
        let contextConfig: ContextConfiguration = try await database.read(
            ChatCommands.FetchContextData(chatId: state.chatId)
        )

        // Build parameters for context builder
        let parameters: BuildParameters = BuildParameters(
            action: modifiedAction,
            contextConfiguration: contextConfig,
            toolResponses: state.toolResults,
            model: state.model
        )

        // Build and return the context
        let context: String = try await contextBuilder.build(parameters: parameters)
        Self.logger.debug("Context built with \(context.count) characters")
        return context
    }

    private func configureSemanticSearchIfNeeded(
        for action: Action,
        chatId: UUID
    ) async throws -> Action {
        // Check for file attachments
        let hasAttachments: Bool = try await database.read(
            ChatCommands.HasAttachments(chatId: chatId)
        )

        guard hasAttachments, let tooling = self.tooling else {
            return action
        }

        Self.logger.debug("Chat has attachments, configuring semantic search tool")

        // Get file titles for context
        let fileTitles: [String] = try await database.read(
            ChatCommands.AttachmentFileTitles(chatId: chatId)
        )

        let fileList: String = fileTitles.joined(separator: ", ")
        Self.logger.debug("Found \(fileTitles.count) attached files: \(fileList)")

        // Configure semantic search tool with file context
        try await tooling.configureSemanticSearch(
            database: database,
            chatId: chatId,
            fileTitles: fileTitles
        )

        // Semantic search is registered dynamically, action remains unchanged
        return action
    }

    private struct StreamState {
        let accumulatedText: String
        let metrics: ChunkMetrics?
        let lastUpdateTime: ContinuousClock.Instant
        let throttleInterval: Duration
    }

    private func initializeStreamState() -> StreamState {
        StreamState(
            accumulatedText: "",
            metrics: nil,
            lastUpdateTime: ContinuousClock.now,
            throttleInterval: Duration.milliseconds(
                AgentOrchestratorConfiguration.shared.streaming.throttleIntervalMilliseconds
            )
        )
    }

    private func processStreamChunks(
        input: LLMInput,
        state: GenerationState,
        streamState: StreamState
    ) async throws -> (String, ChunkMetrics?) {
        var currentText: String = streamState.accumulatedText
        var currentMetrics: ChunkMetrics? = streamState.metrics
        var lastUpdate: ContinuousClock.Instant = streamState.lastUpdateTime
        let throttleInterval: Duration = streamState.throttleInterval

        let streamSequence: AsyncThrowingStream<LLMStreamChunk, Error> =
            await modelCoordinator.stream(input)

        for try await streamChunk in streamSequence {
            currentText += streamChunk.text
            currentMetrics = streamChunk.metrics

            let now: ContinuousClock.Instant = ContinuousClock.now
            let elapsed: Duration = lastUpdate.duration(to: now)

            if elapsed >= throttleInterval {
                try await updatePartialOutput(
                    accumulatedText: currentText,
                    state: state
                )
                lastUpdate = now
            }
        }

        return (currentText, currentMetrics)
    }

    private func finalizeStreamUpdates(
        accumulatedText: String,
        state: GenerationState,
        lastUpdateTime: ContinuousClock.Instant
    ) async throws {
        if lastUpdateTime.duration(to: ContinuousClock.now) > .zero {
            try await updatePartialOutput(
                accumulatedText: accumulatedText,
                state: state
            )}
    }

    private func processStream(
        input: LLMInput,
        state: GenerationState
    ) async throws -> (String, ChunkMetrics?) {
        let streamState: StreamState = initializeStreamState()

        let (accumulatedText, metrics): (String, ChunkMetrics?) = try await processStreamChunks(
            input: input,
            state: state,
            streamState: streamState
        )

        try await finalizeStreamUpdates(
            accumulatedText: accumulatedText,
            state: state,
            lastUpdateTime: streamState.lastUpdateTime
        )

        return (accumulatedText, metrics)
    }

    private func updatePartialOutput(
        accumulatedText: String,
        state: GenerationState
    ) async throws {
        let partialOutput: ProcessedOutput = try await contextBuilder.process(
            output: accumulatedText,
            model: state.model
        )

        try await persistor.updateMessage(
            messageId: state.messageId,
            output: partialOutput
        )
    }

    private func finalizeOutput(
        accumulatedText: String,
        state: GenerationState
    ) async throws -> ProcessedOutput {
        let finalOutput: ProcessedOutput = try await contextBuilder.process(
            output: accumulatedText,
            model: state.model
        )

        try await persistor.updateMessage(
            messageId: state.messageId,
            output: finalOutput
        )

        return finalOutput
    }

    private func executeDecision(
        _ decision: GenerationDecision,
        state: GenerationState
    ) async throws -> GenerationState {
        switch decision {
        case .executeTools(let toolCalls):
            Self.logger.info("Executing tools decision with \(toolCalls.count) tools")
            return try await executeToolsDecision(toolCalls: toolCalls, state: state)

        case .complete:
            Self.logger.info("Executing complete decision")
            return try await completeDecision(state: state)

        case .continueWithNewPrompt(let newPrompt):
            let promptMaxLength: Int = 50
            Self.logger.info("Continuing with new prompt: \(newPrompt.prefix(promptMaxLength))...")
            return state.continueWithPrompt(newPrompt)

        case .error(let error):
            Self.logger.error("Decision resulted in error: \(error.localizedDescription)")
            throw error
        }
    }

    private func executeToolsDecision(
        toolCalls: [ToolRequest],
        state: GenerationState
    ) async throws -> GenerationState {
        Self.logger.notice(
            "Executing \(toolCalls.count) tool calls: \(toolCalls.map(\.name).joined(separator: ", "))"
        )

        let results: [ToolResponse] = await getToolResults(
            toolCalls: toolCalls
        )
        Self.logger.info("Tool execution completed, \(results.count) results received")
        try await persistor.saveToolResults(
            messageId: state.messageId,
            results: results
        )
        return state.continueWithTools(results)
    }

    private func getToolResults(
        toolCalls: [ToolRequest]
    ) async -> [ToolResponse] {
        guard let tooling else {
            Self.logger.warning(
                "Tooling not configured, returning error results for \(toolCalls.count) tool calls"
            )
            return createErrorResults(
                for: toolCalls,
                error: ModelStateCoordinatorError.toolingNotConfigured
            )}

        do {
            Self.logger.debug("Invoking tooling.executeTools with \(toolCalls.count) requests")
            return try await tooling.executeTools(toolRequests: toolCalls)
        } catch {
            Self.logger.error("Tool execution failed: \(error.localizedDescription)")
            return createErrorResults(for: toolCalls, error: error)
        }
    }

    private func createErrorResults(for toolCalls: [ToolRequest], error: Error) -> [ToolResponse] {
        toolCalls.map { toolCall in
            ToolResponse(
                requestId: toolCall.id,
                toolName: toolCall.name,
                result: "Error executing tool: \(error.localizedDescription)",
                error: error.localizedDescription
            )
        }
    }

    private func completeDecision(state: GenerationState) async throws -> GenerationState {
        if let metrics = state.lastMetrics {
            try await persistor.saveStatistics(
                messageId: state.messageId,
                metrics: metrics
            )}
        return state.markComplete()
    }
}
