import Foundation

/// Concrete implementation of Qwen labels
/// ChatML-based with thinking command support
internal struct QwenLabels: QwenLabelsProtocol, ChatMLBaseLabels, ThinkingCommandLabels {
    // Override thinking labels for Qwen 2.5 specific format
    let thinkingStartLabel: String = "<think>"
    let thinkingEndLabel: String = "</think>"

    // ThinkingCommandLabels (Qwen-specific commands)
    let thinkCommand: String? = "/think"
    let noThinkCommand: String? = "/no_think"
}
