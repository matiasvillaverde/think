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

    /// Milliseconds per second for duration calculations
    private static let millisecondsPerSecond: Int = 1_000

    /// Attoseconds to milliseconds divisor
    private static let attosecondsToMilliseconds: Int64 = 1_000_000_000_000_000

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
    private let contextBuilder: any ContextBuilding
    private let tooling: Tooling?
    private let workspaceContextProvider: WorkspaceContextProvider?
    private let workspaceSkillLoader: WorkspaceSkillLoader?
    private let workspaceMemoryLoader: WorkspaceMemoryLoader?
    private var currentChatId: UUID?
    private var eventEmitter: EventEmitter = EventEmitter()
    private let steeringCoordinator: SteeringCoordinator = SteeringCoordinator()

    /// The stream of events emitted during generation
    internal var eventStream: AgentEventStream {
        get async { await eventEmitter.eventStream }
    }

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

    internal func steer(mode: SteeringMode) async {
        await steeringCoordinator.submit(mode: mode)
        Self.logger.info("Steering mode set: \(String(describing: mode))")

        // For hard stop, also trigger model stop
        if mode == .hardStop {
            try? await modelCoordinator.stop()
        }
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
        contextBuilder: any ContextBuilding,
        tooling: Tooling? = nil,
        workspaceContextProvider: WorkspaceContextProvider? = nil,
        workspaceSkillLoader: WorkspaceSkillLoader? = nil,
        workspaceMemoryLoader: WorkspaceMemoryLoader? = nil
    ) {
        self.modelCoordinator = modelCoordinator
        self.persistor = persistor
        self.database = persistor.database
        self.contextBuilder = contextBuilder
        self.tooling = tooling
        self.workspaceContextProvider = workspaceContextProvider
        self.workspaceSkillLoader = workspaceSkillLoader
        self.workspaceMemoryLoader = workspaceMemoryLoader
        self.decisionChain = buildDecisionChain()
    }

    // swiftlint:disable:next function_body_length
    private func orchestrate(request: GenerationRequest) async throws {
        // Reset internal timing state for this generation (stream stays stable)
        await eventEmitter.resetState()

        var state: GenerationState = GenerationState(request: request)
        Self.logger.notice(
            "Starting orchestration for message: \(request.messageId), chat: \(request.chatId)"
        )

        // Emit generation started event
        await eventEmitter.emitGenerationStarted(runId: request.messageId)

        // Clear any previous steering requests
        await steeringCoordinator.clear()

        do {
            while !state.isComplete {
                // Check for steering interrupt at start of iteration
                if let steeringState = await checkSteering(state: state) {
                    state = steeringState
                    if state.isComplete {
                        break
                    }
                }

                Self.logger.info(
                    "Orchestration loop iteration \(state.iterationCount + 1) for message: \(state.messageId)"
                )

                // Emit state update at start of iteration
                await emitStateUpdate(for: state, isExecutingTools: false)

                // Step 1: Stream generation with real-time updates
                state = try await streamGeneration(state)
                state = updateContextUtilization(state)

                // Step 2: Make decision after stream completes
                var decision: GenerationDecision? = try await decisionChain.decide(state)

                // Check steering before tool execution
                if case .executeTools = decision {
                    if await steeringCoordinator.shouldSkipRemainingTools() {
                        Self.logger.info("Steering: Skipping tool execution")
                        decision = .complete
                    }
                }

                Self.logger.info(
                    "Decision made: \(String(describing: decision)) for iteration \(state.iterationCount)"
                )

                // Emit iteration completed event
                await eventEmitter.emitIterationCompleted(
                    iteration: state.iterationCount,
                    decision: describeDecision(decision)
                )

                // Step 3: Execute decision
                state = try await executeDecision(decision ?? .complete, state: state)
            }

            let iterCount: Int = state.iterationCount
            Self.logger.notice(
                "Orchestration completed for message: \(state.messageId) after \(iterCount) iterations"
            )

            // Emit generation completed event
            await eventEmitter.emitGenerationCompleted(runId: request.messageId)
        } catch {
            // Ensure failures are visible in-chat for any client (CLI, UI, etc), not just via
            // transient notifications. We append rather than overwrite so partial output is preserved.
            if !(error is CancellationError) {
                let errorMessage: String = Self.formatGenerationFailureMessage(error)
                do {
                    _ = try await database.write(
                        MessageCommands.AppendFinalChannelContent(
                            messageId: request.messageId,
                            appendedContent: errorMessage,
                            isComplete: true
                        )
                    )
                } catch {
                    Self.logger.debug(
                        "Failed to persist generation failure message: \(error.localizedDescription)"
                    )
                }
            }

            // Emit generation failed event
            await eventEmitter.emitGenerationFailed(runId: request.messageId, error: error)
            throw error
        }
    }

    private static func formatGenerationFailureMessage(_ error: Error) -> String {
        let description: String = error.localizedDescription.trimmingCharacters(
            in: .whitespacesAndNewlines
        )
        if description.isEmpty {
            return "**Generation failed**"
        }
        return """
        **Generation failed**

        \(description)
        """
    }

    private func emitStateUpdate(for state: GenerationState, isExecutingTools: Bool) async {
        let toolNames: [String] = state.pendingToolCalls.map(\.name)
        let stateInfo: GenerationStateInfo = GenerationStateInfo(
            iteration: state.iterationCount,
            isExecutingTools: isExecutingTools,
            activeTools: toolNames,
            completedToolCalls: state.toolResults.count,
            pendingToolCalls: state.pendingToolCalls.count
        )
        await eventEmitter.emitStateUpdate(state: stateInfo)
    }

    private func describeDecision(_ decision: GenerationDecision?) -> String {
        guard let decision else {
            return "complete (default)"
        }
        switch decision {
        case .complete:
            return "complete"

        case .continueWithNewPrompt:
            return "continue with new prompt"

        case .executeTools(let tools):
            return "execute \(tools.count) tool(s)"

        case .error(let error):
            return "error: \(error.localizedDescription)"
        }
    }

    private func checkSteering(state: GenerationState) async -> GenerationState? {
        guard let request = await steeringCoordinator.consume() else {
            return nil
        }

        Self.logger.info("Processing steering request: \(request.id)")

        switch request.mode {
        case .inactive:
            return nil

        case .hardStop:
            Self.logger.info("Hard stop requested - completing generation")
            return state.markComplete()

        case .softInterrupt:
            Self.logger.info("Soft interrupt - will complete after current operation")
            return state.markComplete()

        case .redirect(let newPrompt):
            Self.logger.info("Redirect requested with new prompt")
            return state.continueWithPrompt(newPrompt)
        }
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

    private func updateContextUtilization(_ state: GenerationState) -> GenerationState {
        guard let utilization: Double = state.lastMetrics?.usage?.contextUtilization else {
            return state
        }
        return state.withContextUtilization(utilization)
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
        logContextStart(for: state)
        let prepared: (Action, ContextConfiguration) = try await prepareActionWithPolicy(state: state)
        let parameters: BuildParameters = buildParameters(
            for: state,
            action: prepared.0,
            contextConfig: prepared.1
        )
        let context: String = try await contextBuilder.build(parameters: parameters)
        Self.logger.debug("Context built with \(context.count) characters")
        return context
    }

    /// Prepares action with semantic search and applies tool policy filtering
    private func prepareActionWithPolicy(
        state: GenerationState
    ) async throws -> (Action, ContextConfiguration) {
        let modifiedAction: Action = try await configureSemanticSearchIfNeeded(
            for: state.action,
            chatId: state.chatId
        )
        let baseConfig: ContextConfiguration = try await fetchContextConfiguration(
            chatId: state.chatId
        )
        let contextConfig: ContextConfiguration = applyWorkspaceContextAndSkills(
            baseConfig
        )
        let policyFilteredAction: Action = applyToolPolicy(
            action: modifiedAction,
            allowedTools: contextConfig.allowedTools,
            hasToolPolicy: contextConfig.hasToolPolicy
        )
        return (policyFilteredAction, contextConfig)
    }

    private func applyWorkspaceContextAndSkills(
        _ contextConfig: ContextConfiguration
    ) -> ContextConfiguration {
        let workspaceContext: WorkspaceContext? = workspaceContextProvider?.loadContext()
        let mergedMemoryContext: MemoryContext? = mergeWorkspaceMemory(from: contextConfig)
        let mergedSkillContext: SkillContext? = mergeWorkspaceSkills(from: contextConfig)

        return mergeContextConfiguration(
            base: contextConfig,
            workspaceContext: workspaceContext,
            memoryContext: mergedMemoryContext,
            skillContext: mergedSkillContext
        )
    }

    private func mergeWorkspaceMemory(from contextConfig: ContextConfiguration) -> MemoryContext? {
        let workspaceMemory: MemoryContext? = workspaceMemoryLoader?.loadContext()
        return MemoryContextMerger.merge(
            primary: contextConfig.memoryContext,
            secondary: workspaceMemory
        )
    }

    private func mergeWorkspaceSkills(from contextConfig: ContextConfiguration) -> SkillContext? {
        let workspaceSkills: [SkillData] = workspaceSkillLoader?.loadSkills() ?? []
        return mergeSkillContext(current: contextConfig.skillContext, additional: workspaceSkills)
    }

    private func mergeContextConfiguration(
        base: ContextConfiguration,
        workspaceContext: WorkspaceContext?,
        memoryContext: MemoryContext?,
        skillContext: SkillContext?
    ) -> ContextConfiguration {
        ContextConfiguration(
            systemInstruction: base.systemInstruction,
            contextMessages: base.contextMessages,
            maxPrompt: base.maxPrompt,
            includeCurrentDate: base.includeCurrentDate,
            knowledgeCutoffDate: base.knowledgeCutoffDate,
            currentDateOverride: base.currentDateOverride,
            memoryContext: memoryContext,
            skillContext: skillContext,
            workspaceContext: workspaceContext ?? base.workspaceContext,
            allowedTools: base.allowedTools,
            hasToolPolicy: base.hasToolPolicy
        )
    }

    private func mergeSkillContext(
        current: SkillContext?,
        additional: [SkillData]
    ) -> SkillContext? {
        guard !additional.isEmpty else {
            return current
        }

        let existingSkills: [SkillData] = current?.activeSkills ?? []
        var merged: [SkillData] = existingSkills
        let existingNames: Set<String> = Set(existingSkills.map { $0.name.lowercased() })

        for skill in additional where !existingNames.contains(skill.name.lowercased()) {
            merged.append(skill)
        }

        return merged.isEmpty ? nil : SkillContext(activeSkills: merged)
    }

    /// Filters the action's tools against the personality tool policy
    private func applyToolPolicy(
        action: Action,
        allowedTools: Set<ToolIdentifier>,
        hasToolPolicy: Bool
    ) -> Action {
        // If no explicit policy defined, allow all tools (don't filter)
        guard hasToolPolicy else {
            return action
        }

        let currentTools: Set<ToolIdentifier> = action.tools
        let filteredTools: Set<ToolIdentifier> = currentTools.intersection(allowedTools)

        if filteredTools.count < currentTools.count {
            let blocked: Set<ToolIdentifier> = currentTools.subtracting(filteredTools)
            Self.logger.info("Tool policy blocked \(blocked.count) tool(s): \(blocked.map(\.rawValue))")
        }

        switch action {
        case .textGeneration:
            return .textGeneration(filteredTools)

        case .imageGeneration:
            return .imageGeneration(filteredTools)
        }
    }

    private func applyPromptOverride(
        for state: GenerationState,
        to contextConfig: ContextConfiguration
    ) -> ContextConfiguration {
        ContextConfiguration(
            systemInstruction: contextConfig.systemInstruction,
            contextMessages: overrideContextMessages(
                for: state,
                in: contextConfig.contextMessages
            ),
            maxPrompt: contextConfig.maxPrompt,
            includeCurrentDate: contextConfig.includeCurrentDate,
            knowledgeCutoffDate: contextConfig.knowledgeCutoffDate,
            currentDateOverride: contextConfig.currentDateOverride,
            memoryContext: contextConfig.memoryContext,
            skillContext: contextConfig.skillContext,
            workspaceContext: contextConfig.workspaceContext,
            allowedTools: contextConfig.allowedTools,
            hasToolPolicy: contextConfig.hasToolPolicy
        )
    }

    private func overrideContextMessages(
        for state: GenerationState,
        in messages: [MessageData]
    ) -> [MessageData] {
        messages.map { message in
            guard message.id == state.messageId else {
                return message
            }
            return MessageData(
                id: message.id,
                createdAt: message.createdAt,
                userInput: state.prompt,
                channels: message.channels,
                toolCalls: message.toolCalls
            )
        }
    }

    private func logContextStart(for state: GenerationState) {
        let hasToolResults: Bool = !state.toolResults.isEmpty
        Self.logger.debug(
            "Building context for iteration \(state.iterationCount), has tool results: \(hasToolResults)"
        )
    }

    private func fetchContextConfiguration(chatId: UUID) async throws -> ContextConfiguration {
        try await database.read(ChatCommands.FetchContextData(chatId: chatId))
    }

    private func buildParameters(
        for state: GenerationState,
        action: Action,
        contextConfig: ContextConfiguration
    ) -> BuildParameters {
        BuildParameters(
            action: action,
            contextConfiguration: applyPromptOverride(for: state, to: contextConfig),
            toolResponses: state.toolResults,
            model: state.model
        )
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
        await tooling.configureSemanticSearch(
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

    private struct StreamChunkContext {
        let state: GenerationState
        let throttleInterval: Duration
        var currentText: String
        var currentMetrics: ChunkMetrics?
        var lastUpdate: ContinuousClock.Instant
        var hasInitializedChannels: Bool
    }

    private struct StreamChunkResult {
        let accumulatedText: String
        let metrics: ChunkMetrics?
        let didInitializeChannels: Bool
        let lastUpdateTime: ContinuousClock.Instant
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
    ) async throws -> StreamChunkResult {
        var chunkContext: StreamChunkContext = StreamChunkContext(
            state: state,
            throttleInterval: streamState.throttleInterval,
            currentText: streamState.accumulatedText,
            currentMetrics: streamState.metrics,
            lastUpdate: streamState.lastUpdateTime,
            hasInitializedChannels: false
        )

        let streamSequence: AsyncThrowingStream<LLMStreamChunk, Error> =
            await modelCoordinator.stream(input)

        for try await streamChunk in streamSequence {
            try await handleStreamChunk(streamChunk, context: &chunkContext)
        }

        return StreamChunkResult(
            accumulatedText: chunkContext.currentText,
            metrics: chunkContext.currentMetrics,
            didInitializeChannels: chunkContext.hasInitializedChannels,
            lastUpdateTime: chunkContext.lastUpdate
        )
    }

    private func handleStreamChunk(
        _ streamChunk: LLMStreamChunk,
        context: inout StreamChunkContext
    ) async throws {
        if !streamChunk.text.isEmpty {
            await eventEmitter.emitTextDelta(text: streamChunk.text)
        }

        context.currentText += streamChunk.text
        context.currentMetrics = streamChunk.metrics

        let now: ContinuousClock.Instant = ContinuousClock.now
        let elapsed: Duration = context.lastUpdate.duration(to: now)

        if elapsed >= context.throttleInterval {
            try await updateStreamingOutput(context: &context)
            context.lastUpdate = now
        }
    }

    private func finalizeStreamUpdates(
        accumulatedText: String,
        state: GenerationState,
        lastUpdateTime: ContinuousClock.Instant,
        didInitializeChannels: Bool
    ) async throws {
        guard lastUpdateTime.duration(to: ContinuousClock.now) > .zero else {
            return
        }

        if didInitializeChannels {
            try await persistor.updateStreamingFinalChannel(
                messageId: state.messageId,
                content: StreamingFinalChannelExtractor.extract(from: accumulatedText),
                isComplete: false
            )
            return
        }

        let partialOutput: ProcessedOutput = try await contextBuilder.process(
            output: accumulatedText,
            model: state.model
        )
        try await persistor.updateMessage(
            messageId: state.messageId,
            output: partialOutput
        )
    }

    private func updateStreamingOutput(context: inout StreamChunkContext) async throws {
        if context.hasInitializedChannels == false {
            // First update: run the full parser once to establish stable channel UUIDs.
            let partialOutput: ProcessedOutput = try await contextBuilder.process(
                output: context.currentText,
                model: context.state.model
            )
            try await persistor.updateMessage(
                messageId: context.state.messageId,
                output: partialOutput
            )
            context.hasInitializedChannels = true
            return
        }

        // Subsequent updates: update only the final channel content (cheap, avoids re-processing
        // accumulated output over and over as it grows).
        let userFacingText: String = StreamingFinalChannelExtractor.extract(from: context.currentText)
        try await persistor.updateStreamingFinalChannel(
            messageId: context.state.messageId,
            content: userFacingText,
            isComplete: false
        )
    }

    private func processStream(
        input: LLMInput,
        state: GenerationState
    ) async throws -> (String, ChunkMetrics?) {
        let streamState: StreamState = initializeStreamState()

        let result: StreamChunkResult = try await processStreamChunks(
            input: input,
            state: state,
            streamState: streamState
        )

        try await finalizeStreamUpdates(
            accumulatedText: result.accumulatedText,
            state: state,
            lastUpdateTime: result.lastUpdateTime,
            didInitializeChannels: result.didInitializeChannels
        )

        return (result.accumulatedText, result.metrics)
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
            var updatedState: GenerationState = state.continueWithPrompt(newPrompt)
            if newPrompt == AgentOrchestratorConfiguration.shared.compaction.flushPrompt {
                updatedState = updatedState.markMemoryFlushPerformed()
            }
            return updatedState

        case .error(let error):
            Self.logger.error("Decision resulted in error: \(error.localizedDescription)")
            throw error
        }
    }

    private func executeToolsDecision(
        toolCalls: [ToolRequest],
        state: GenerationState
    ) async throws -> GenerationState {
        logToolExecution(toolCalls)
        await emitStateUpdate(for: state, isExecutingTools: true)

        let toolPolicy: ToolPolicySnapshot = await fetchToolPolicy(chatId: state.chatId)
        let toolCallsWithContext: [ToolRequest] = attachToolContext(
            toolCalls: toolCalls,
            state: state,
            toolPolicy: toolPolicy
        )
        let results: [ToolResponse] = await getToolResultsWithEvents(
            toolCalls: toolCallsWithContext
        )
        Self.logger.info("Tool execution completed, \(results.count) results received")
        try await persistor.saveToolResults(
            messageId: state.messageId,
            results: results
        )
        return state.continueWithTools(results)
    }

    private func logToolExecution(_ toolCalls: [ToolRequest]) {
        let toolNames: [String] = toolCalls.map(\.name)
        Self.logger.notice(
            "Executing \(toolCalls.count) tool calls: \(toolNames.joined(separator: ", "))"
        )
    }

    private func attachToolContext(
        toolCalls: [ToolRequest],
        state: GenerationState,
        toolPolicy: ToolPolicySnapshot
    ) -> [ToolRequest] {
        toolCalls.map { toolCall in
            toolCall.withContext(
                chatId: state.chatId,
                messageId: state.messageId,
                hasToolPolicy: toolPolicy.hasToolPolicy,
                allowedToolNames: toolPolicy.allowedToolNames
            )
        }
    }

    private struct ToolPolicySnapshot {
        let hasToolPolicy: Bool
        let allowedToolNames: [String]

        static let allowAll: ToolPolicySnapshot = ToolPolicySnapshot(
            hasToolPolicy: false,
            allowedToolNames: []
        )
    }

    private func fetchToolPolicy(chatId: UUID) async -> ToolPolicySnapshot {
        do {
            let contextConfig: ContextConfiguration = try await fetchContextConfiguration(
                chatId: chatId
            )
            guard contextConfig.hasToolPolicy else {
                return .allowAll
            }
            return ToolPolicySnapshot(
                hasToolPolicy: true,
                allowedToolNames: contextConfig.allowedTools.map(\.toolName)
            )
        } catch {
            let errorDescription: String = error.localizedDescription
            Self.logger.warning(
                "Tool policy fetch failed for chat \(chatId, privacy: .public): \(errorDescription)"
            )
            return .allowAll
        }
    }

    // swiftlint:disable:next function_body_length
    private func getToolResultsWithEvents(
        toolCalls: [ToolRequest]
    ) async -> [ToolResponse] {
        // Emit tool started events for all tools
        for toolCall in toolCalls {
            await eventEmitter.emitToolStarted(requestId: toolCall.id, toolName: toolCall.name)
        }

        let startTime: ContinuousClock.Instant = ContinuousClock().now

        guard let tooling else {
            Self.logger.warning(
                "Tooling not configured, returning error results for \(toolCalls.count) tool calls"
            )
            let errorResults: [ToolResponse] = createErrorResults(
                for: toolCalls,
                error: ModelStateCoordinatorError.toolingNotConfigured
            )
            // Emit tool failed events
            for result in errorResults {
                await eventEmitter.emitToolFailed(
                    requestId: result.requestId,
                    error: result.error ?? "Tool execution failed"
                )
            }
            return errorResults
        }

        Self.logger.debug("Invoking tooling.executeTools with \(toolCalls.count) requests")
        let results: [ToolResponse] = await tooling.executeTools(toolRequests: toolCalls)

        // Calculate total duration
        let elapsed: Duration = startTime.duration(to: ContinuousClock().now)
        let secondsMs: Int = Int(elapsed.components.seconds) * Self.millisecondsPerSecond
        let attosecondsMs: Int = Int(elapsed.components.attoseconds / Self.attosecondsToMilliseconds)
        let durationMs: Int = secondsMs + attosecondsMs

        // Emit tool completed/failed events
        for result in results {
            if let error = result.error {
                await eventEmitter.emitToolFailed(requestId: result.requestId, error: error)
            } else {
                await eventEmitter.emitToolCompleted(
                    requestId: result.requestId,
                    result: result.result,
                    durationMs: durationMs
                )
            }
        }

        return results
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
            )
        }

        Self.logger.debug("Invoking tooling.executeTools with \(toolCalls.count) requests")
        return await tooling.executeTools(toolRequests: toolCalls)
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
