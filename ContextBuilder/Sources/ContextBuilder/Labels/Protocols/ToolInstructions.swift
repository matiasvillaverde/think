import Foundation

/// Protocol for tool instruction templates
internal protocol ToolInstructions {
    /// Section title for tools (e.g., "# Tools Available")
    var toolSectionTitle: String { get }

    /// Introduction text explaining how tools work
    var toolIntroduction: String { get }

    /// Instructions on how to call functions
    var toolCallInstructions: String { get }

    /// Important instructions list
    var toolImportantInstructions: [String] { get }

    /// Whether to use array format [tool1, tool2] vs separate lines
    var useArrayFormat: Bool { get }
}
