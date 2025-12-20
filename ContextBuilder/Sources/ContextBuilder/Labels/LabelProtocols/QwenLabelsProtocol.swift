import Foundation

/// Composite protocol for Qwen models
/// Extends ChatML with thinking command support
internal protocol QwenLabelsProtocol: CoreRoleLabels,
    InformationLabels,
    ToolCallingLabels,
    ThinkingLabels,
    ThinkingCommandLabels,
    CommentaryLabels,
    StopSequenceLabels {}
