import Abstractions

extension ContextConfiguration {
    internal func withMessages(_ messages: [MessageData]) -> ContextConfiguration {
        ContextConfiguration(
            systemInstruction: systemInstruction,
            contextMessages: messages,
            maxPrompt: maxPrompt,
            reasoningLevel: reasoningLevel,
            includeCurrentDate: includeCurrentDate,
            knowledgeCutoffDate: knowledgeCutoffDate,
            currentDateOverride: currentDateOverride,
            memoryContext: memoryContext,
            skillContext: skillContext,
            workspaceContext: workspaceContext,
            allowedTools: allowedTools,
            hasToolPolicy: hasToolPolicy
        )
    }
}
