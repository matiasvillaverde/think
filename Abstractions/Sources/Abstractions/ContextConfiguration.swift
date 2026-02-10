import Foundation

/// Configuration for building context from chat data
public struct ContextConfiguration: Sendable {
    public let systemInstruction: String
    public let contextMessages: [MessageData]
    public let maxPrompt: Int  // Maximum tokens the model can digest (context length)
    public let includeCurrentDate: Bool
    public let knowledgeCutoffDate: String?
    public let currentDateOverride: String?
    /// Memory context to inject into the system prompt
    public let memoryContext: MemoryContext?
    /// Skill context to inject tool usage guidance into the system prompt
    public let skillContext: SkillContext?
    /// Workspace context to inject bootstrap files into the system prompt
    public let workspaceContext: WorkspaceContext?
    /// Allowed tools based on resolved personality tool policy (empty means no tools allowed)
    public let allowedTools: Set<ToolIdentifier>
    /// Whether a tool policy was explicitly set (if false, allowedTools contains all tools)
    public let hasToolPolicy: Bool

    public init(
        systemInstruction: String,
        contextMessages: [MessageData],
        maxPrompt: Int,
        includeCurrentDate: Bool = true,
        knowledgeCutoffDate: String? = nil,
        currentDateOverride: String? = nil,
        memoryContext: MemoryContext? = nil,
        skillContext: SkillContext? = nil,
        workspaceContext: WorkspaceContext? = nil,
        allowedTools: Set<ToolIdentifier> = Set(ToolIdentifier.allCases),
        hasToolPolicy: Bool = false
    ) {
        self.systemInstruction = systemInstruction
        self.contextMessages = contextMessages
        self.maxPrompt = maxPrompt
        self.includeCurrentDate = includeCurrentDate
        self.knowledgeCutoffDate = knowledgeCutoffDate
        self.currentDateOverride = currentDateOverride
        self.memoryContext = memoryContext
        self.skillContext = skillContext
        self.workspaceContext = workspaceContext
        self.allowedTools = allowedTools
        self.hasToolPolicy = hasToolPolicy
    }
}
