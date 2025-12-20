import Foundation

/// Error type for tool execution
public struct ToolError: Error {
    /// The error message
    public let message: String

    /// Initialize with an error message
    /// - Parameter message: The error message
    public init(_ message: String) {
        self.message = message
    }
}
