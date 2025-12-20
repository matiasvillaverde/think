import Foundation

/// Concrete implementation of ChatML labels
/// Used by models like Qwen, Yi, SmolLM, and others
/// All properties are provided by ChatMLBaseLabels protocol extensions
internal struct ChatMLLabels: ChatMLLabelsProtocol, ChatMLBaseLabels {}
