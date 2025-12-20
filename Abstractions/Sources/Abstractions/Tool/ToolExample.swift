import Foundation

/// Example of how to use a tool in a specific scenario
public struct ToolExample: Codable, Sendable, Equatable {
    /// Description of the scenario where this tool would be used
    public let scenario: String

    /// Example input in JSON format
    public let input: String

    /// Expected behavior or output description
    public let expectedBehavior: String

    public init(scenario: String, input: String, expectedBehavior: String) {
        self.scenario = scenario
        self.input = input
        self.expectedBehavior = expectedBehavior
    }
}
