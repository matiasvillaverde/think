import Foundation

/// Configuration for building context from chat data
public struct ContextConfiguration: Sendable {
    public let systemInstruction: String
    public let contextMessages: [MessageData]
    public let maxPrompt: Int  // Maximum tokens the model can digest (context length)
    public let reasoningLevel: String?
    public let includeCurrentDate: Bool
    public let knowledgeCutoffDate: String?
    public let currentDateOverride: String?
    /// Memory context to inject into the system prompt
    public let memoryContext: MemoryContext?
    /// Skill context to inject tool usage guidance into the system prompt
    public let skillContext: SkillContext?

    public init(
        systemInstruction: String,
        contextMessages: [MessageData],
        maxPrompt: Int,
        reasoningLevel: String? = nil,
        includeCurrentDate: Bool = true,
        knowledgeCutoffDate: String? = nil,
        currentDateOverride: String? = nil,
        memoryContext: MemoryContext? = nil,
        skillContext: SkillContext? = nil
    ) {
        self.systemInstruction = systemInstruction
        self.contextMessages = contextMessages
        self.maxPrompt = maxPrompt
        self.reasoningLevel = reasoningLevel
        self.includeCurrentDate = includeCurrentDate
        self.knowledgeCutoffDate = knowledgeCutoffDate
        self.currentDateOverride = currentDateOverride
        self.memoryContext = memoryContext
        self.skillContext = skillContext
    }
}
