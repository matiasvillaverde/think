import Foundation

/// Composite protocol for ChatML-style models
/// Combines core, information, tools, thinking, commentary, and stop sequences
internal protocol ChatMLLabelsProtocol: CoreRoleLabels,
    InformationLabels,
    ToolCallingLabels,
    ThinkingLabels,
    CommentaryLabels,
    StopSequenceLabels {}
