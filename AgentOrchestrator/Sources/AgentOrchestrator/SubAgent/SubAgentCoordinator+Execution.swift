import Abstractions
import ContextBuilder
import Database
import Foundation
import Tools

extension SubAgentCoordinator {
    internal func executeSubAgent(request: SubAgentRequest) async -> SubAgentResult {
        let startTime: Date = Date()
        Self.logger.info("Executing sub-agent: \(request.id)")

        let runId: UUID? = await createRun(for: request)
        let result: SubAgentResult = await runWithTimeout(request: request, startTime: startTime)

        await updateRun(runId: runId, with: result)
        return recordResult(result)
    }

    private func createRun(for request: SubAgentRequest) async -> UUID? {
        let toolNames: [String] = request.tools.map(\.toolName)

        return try? await database.write(SubAgentCommands.Create(
            prompt: request.prompt,
            mode: request.mode,
            tools: toolNames,
            parentMessageId: request.parentMessageId,
            chatId: request.parentChatId
        ))
    }

    private func runWithTimeout(
        request: SubAgentRequest,
        startTime: Date
    ) async -> SubAgentResult {
        do {
            return try await runRequestWithTimeout(request: request, startTime: startTime)
        } catch is CancellationError {
            return makeCancelledResult(id: request.id, startTime: startTime)
        } catch {
            return makeFailureResult(
                id: request.id,
                error: error.localizedDescription,
                startTime: startTime
            )
        }
    }

    private func runRequestWithTimeout(
        request: SubAgentRequest,
        startTime: Date
    ) async throws -> SubAgentResult {
        try await withThrowingTaskGroup(of: SubAgentResult.self) { group in
            group.addTask {
                try await self.performSubAgentRun(request: request, startTime: startTime)
            }

            group.addTask {
                try await Task.sleep(for: request.timeout)
                return SubAgentResult.timedOut(
                    id: request.id,
                    durationMs: SubAgentCoordinator.elapsedMs(since: startTime)
                )
            }

            guard let firstResult = try await group.next() else {
                throw SubAgentError.executionFailed("No result")
            }

            group.cancelAll()
            return firstResult
        }
    }

    private func performSubAgentRun(
        request: SubAgentRequest,
        startTime: Date
    ) async throws -> SubAgentResult {
        let runContext: SubAgentRunContext = try await prepareRunContext(request: request)
        let tooling: SubAgentTooling = createTooling()
        return try await runToolLoop(
            request: request,
            runContext: runContext,
            tooling: tooling,
            startTime: startTime
        )
    }

    private func prepareRunContext(request: SubAgentRequest) async throws -> SubAgentRunContext {
        let model: SendableModel = try await loadModel(chatId: request.parentChatId)
        let baseConfig: ContextConfiguration = try await loadBaseConfiguration(
            chatId: request.parentChatId
        )
        let config: ContextConfiguration = buildContextConfiguration(
            request: request,
            baseConfig: baseConfig
        )
        let action: Action = applyToolPolicy(
            action: .textGeneration(request.tools),
            allowedTools: config.allowedTools,
            hasToolPolicy: config.hasToolPolicy
        )

        return SubAgentRunContext(model: model, action: action, contextConfig: config)
    }

    private func loadModel(chatId: UUID) async throws -> SendableModel {
        let model: SendableModel = try await database.read(
            ChatCommands.GetLanguageModel(chatId: chatId)
        )
        try await modelCoordinator.load(chatId: chatId)
        return model
    }

    private func loadBaseConfiguration(chatId: UUID) async throws -> ContextConfiguration {
        try await database.read(ChatCommands.FetchContextData(chatId: chatId))
    }

    private func buildContextConfiguration(
        request: SubAgentRequest,
        baseConfig: ContextConfiguration
    ) -> ContextConfiguration {
        let systemInstruction: String = request.systemInstruction ?? baseConfig.systemInstruction
        let mergedSkills: SkillContext? = mergeWorkspaceSkills(baseConfig: baseConfig)
        let mergedMemory: MemoryContext? = mergeWorkspaceMemory(baseConfig: baseConfig)
        let workspaceContext: WorkspaceContext? = workspaceContextProvider?.loadContext()

        return ContextConfiguration(
            systemInstruction: systemInstruction,
            contextMessages: [],
            maxPrompt: baseConfig.maxPrompt,
            includeCurrentDate: baseConfig.includeCurrentDate,
            knowledgeCutoffDate: baseConfig.knowledgeCutoffDate,
            currentDateOverride: baseConfig.currentDateOverride,
            memoryContext: mergedMemory,
            skillContext: mergedSkills,
            workspaceContext: workspaceContext ?? baseConfig.workspaceContext,
            allowedTools: baseConfig.allowedTools,
            hasToolPolicy: baseConfig.hasToolPolicy
        )
    }

    private func mergeWorkspaceSkills(baseConfig: ContextConfiguration) -> SkillContext? {
        let workspaceSkills: [SkillData] = workspaceSkillLoader?.loadSkills() ?? []
        return mergeSkillContext(current: baseConfig.skillContext, additional: workspaceSkills)
    }

    private func mergeWorkspaceMemory(baseConfig: ContextConfiguration) -> MemoryContext? {
        let workspaceMemory: MemoryContext? = workspaceMemoryLoader?.loadContext()
        return MemoryContextMerger.merge(
            primary: baseConfig.memoryContext,
            secondary: workspaceMemory
        )
    }

    private func createTooling() -> SubAgentTooling {
        let toolManager: ToolManager = ToolManager(workspaceRoot: workspaceRoot)
        let contextBuilder: ContextBuilder = ContextBuilder(tooling: toolManager)
        return SubAgentTooling(toolManager: toolManager, contextBuilder: contextBuilder)
    }

    private func makeToolLoopInputs(
        request: SubAgentRequest,
        runContext: SubAgentRunContext,
        tooling: SubAgentTooling,
        startTime: Date
    ) -> ToolLoopInputs {
        ToolLoopInputs(
            request: request,
            runContext: runContext,
            tooling: tooling,
            startTime: startTime
        )
    }

    private func initialToolLoopState(runContext: SubAgentRunContext) -> ToolLoopState {
        ToolLoopState(
            toolResponses: [],
            toolsUsed: [],
            contextConfig: runContext.contextConfig
        )
    }

    private func runIteration(
        iteration: Int,
        inputs: ToolLoopInputs,
        state: ToolLoopState
    ) async throws -> ToolLoopOutcome {
        let output: IterationOutput = try await generateIterationOutput(inputs: inputs, state: state)
        if let outcome = completionOutcome(
            iteration: iteration,
            inputs: inputs,
            state: state,
            output: output
        ) {
            return outcome
        }

        let execution: ToolExecutionResult = await executeTools(
            toolRequests: output.toolRequests,
            action: inputs.runContext.action,
            toolManager: inputs.tooling.toolManager
        )
        let nextState: ToolLoopState = advanceState(
            state: state,
            contextConfig: output.contextConfig,
            execution: execution
        )
        return .continue(nextState)
    }

    private func generateIterationOutput(
        inputs: ToolLoopInputs,
        state: ToolLoopState
    ) async throws -> IterationOutput {
        let requestContext: ContextConfiguration = applyRequestContext(
            request: inputs.request, contextConfig: state.contextConfig
        )
        let generated: GeneratedOutput = try await generateOnce(
            request: inputs.request,
            contextConfig: requestContext,
            toolResponses: state.toolResponses,
            runContext: inputs.runContext,
            tooling: inputs.tooling
        )
        let toolRequests: [ToolRequest] = generated.processed.toolRequests
        let updatedContext: ContextConfiguration = applyToolContext(
            request: inputs.request,
            contextConfig: requestContext,
            generated: generated,
            toolRequests: toolRequests
        )
        return IterationOutput(
            generated: generated, toolRequests: toolRequests, contextConfig: updatedContext
        )
    }

    private func completionOutcome(
        iteration: Int,
        inputs: ToolLoopInputs,
        state: ToolLoopState,
        output: IterationOutput
    ) -> ToolLoopOutcome? {
        if output.toolRequests.isEmpty {
            let result: SubAgentResult = makeCompletedResult(
                requestId: inputs.request.id,
                output: output.generated.output,
                toolsUsed: state.toolsUsed,
                startTime: inputs.startTime
            )
            return .completed(result)
        }

        if iteration == Constants.maxIterations - 1 {
            let result: SubAgentResult = makeIterationFailureResult(
                requestId: inputs.request.id,
                startTime: inputs.startTime
            )
            return .failed(result)
        }

        return nil
    }

    private func advanceState(
        state: ToolLoopState,
        contextConfig: ContextConfiguration,
        execution: ToolExecutionResult
    ) -> ToolLoopState {
        let mergedTools: [String] = mergeToolUsage(
            current: state.toolsUsed,
            additional: execution.toolsUsed
        )
        return ToolLoopState(
            toolResponses: execution.responses,
            toolsUsed: mergedTools,
            contextConfig: contextConfig
        )
    }

    private func runToolLoop(
        request: SubAgentRequest,
        runContext: SubAgentRunContext,
        tooling: SubAgentTooling,
        startTime: Date
    ) async throws -> SubAgentResult {
        let inputs: ToolLoopInputs = makeToolLoopInputs(
            request: request, runContext: runContext, tooling: tooling, startTime: startTime
        )
        var state: ToolLoopState = initialToolLoopState(runContext: runContext)

        for iteration in 0..<Constants.maxIterations {
            let outcome: ToolLoopOutcome = try await runIteration(
                iteration: iteration,
                inputs: inputs,
                state: state
            )
            switch outcome {
            case .completed(let result), .failed(let result):
                return result

            case .continue(let nextState):
                state = nextState
            }
        }

        return makeIterationFailureResult(requestId: request.id, startTime: startTime)
    }

    private func generateOnce(
        request: SubAgentRequest,
        contextConfig: ContextConfiguration,
        toolResponses: [ToolResponse],
        runContext: SubAgentRunContext,
        tooling: SubAgentTooling
    ) async throws -> GeneratedOutput {
        let parameters: BuildParameters = BuildParameters(
            action: runContext.action,
            contextConfiguration: contextConfig,
            toolResponses: toolResponses,
            model: runContext.model
        )
        let context: String = try await tooling.contextBuilder.build(parameters: parameters)
        let input: LLMInput = try await buildInput(
            request: request,
            model: runContext.model,
            context: context,
            contextBuilder: tooling.contextBuilder
        )
        let outputText: String = try await streamToString(input: input)
        let processed: ProcessedOutput = try await tooling.contextBuilder.process(
            output: outputText,
            model: runContext.model
        )
        let output: String = extractFinalOutput(from: processed, fallback: outputText)
        return GeneratedOutput(output: output, processed: processed)
    }

    private func buildInput(
        request: SubAgentRequest,
        model: SendableModel,
        context: String,
        contextBuilder: ContextBuilder
    ) async throws -> LLMInput {
        let inputBuilder: LLMInputBuilder = LLMInputBuilder(
            chat: request.parentChatId,
            model: model,
            database: database,
            contextBuilder: contextBuilder
        )
        return try await inputBuilder.build(context: context)
    }

    private func executeTools(
        toolRequests: [ToolRequest],
        action: Action,
        toolManager: ToolManager
    ) async -> ToolExecutionResult {
        let allowedToolNames: Set<String> = Set(action.tools.map(\.toolName))
        let partitioned: ToolPartition = partitionToolRequests(
            toolRequests,
            allowed: allowedToolNames
        )
        let blockedResponses: [ToolResponse] = makeBlockedResponses(from: partitioned.blocked)
        let allowedResponses: [ToolResponse] = await toolManager.executeTools(
            toolRequests: partitioned.allowed
        )
        let toolsUsed: [String] = collectToolNames(
            allowed: allowedResponses,
            blocked: partitioned.blocked
        )

        return ToolExecutionResult(
            responses: allowedResponses + blockedResponses,
            toolsUsed: toolsUsed
        )
    }
}
