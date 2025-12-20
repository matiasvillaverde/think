import Foundation

/// Widget example structure for model cards
///
/// Represents example inputs/outputs displayed in HuggingFace model cards
/// to demonstrate model capabilities. These examples help users understand
/// how to use the model effectively.
///
/// ## Usage
/// ```swift
/// let example = WidgetExample(
///     text: "What is the capital of France?",
///     exampleTitle: "Geography Question"
/// )
/// ```
public struct WidgetExample: Sendable, Codable, Equatable, Hashable {
    /// The example text input or output
    public let text: String?

    /// Human-readable title for this example
    public let exampleTitle: String?

    /// Initialize a new widget example
    /// - Parameters:
    ///   - text: The example text content
    ///   - exampleTitle: Optional title describing the example
    public init(text: String? = nil, exampleTitle: String? = nil) {
        self.text = text
        self.exampleTitle = exampleTitle
    }

    private enum CodingKeys: String, CodingKey {
        case text
        case exampleTitle = "example_title"
    }
}
