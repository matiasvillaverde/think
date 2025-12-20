import Foundation

/// Protocol for validating tool requirements before execution
public protocol ToolValidating: Sendable {
    /// Validates if a tool can be executed based on current system state
    /// - Parameters:
    ///   - tool: The tool to validate
    ///   - chatId: The chat session identifier
    /// - Returns: The validation result indicating tool availability
    func validateToolRequirements(_ tool: ToolIdentifier, chatId: UUID) async throws -> ToolValidationResult
}
