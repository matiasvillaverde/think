import Foundation

/// Protocol for tools with enhanced metadata for better context building
public protocol EnhancedToolProtocol {
    /// Instructions on when to use this tool
    var usageInstruction: String? { get }

    /// Concrete examples of tool usage
    var examples: [ToolExample] { get }

    /// How this tool interacts with other tools
    var interactionPattern: InteractionPattern? { get }

    /// Prerequisites that must be met before using this tool
    var prerequisites: [String] { get }

    /// Best practices and additional guidance for using this tool
    var bestPractices: String? { get }
}
