import Foundation

/// Concrete implementation of enhanced tool metadata
public struct EnhancedToolMetadata: EnhancedToolProtocol, Codable, Sendable, Equatable {
    public let usageInstruction: String?
    public let examples: [ToolExample]
    public let interactionPattern: InteractionPattern?
    public let prerequisites: [String]
    public let bestPractices: String?

    public init(
        usageInstruction: String? = nil,
        examples: [ToolExample] = [],
        interactionPattern: InteractionPattern? = nil,
        prerequisites: [String] = [],
        bestPractices: String? = nil
    ) {
        self.usageInstruction = usageInstruction
        self.examples = examples
        self.interactionPattern = interactionPattern
        self.prerequisites = prerequisites
        self.bestPractices = bestPractices
    }
}
