import Foundation

/// Composite protocol for Mistral models
/// Uses custom format with [INST] markers
internal protocol MistralLabelsProtocol: CoreRoleLabels,
    InformationLabels,
    ToolCallingLabels,
    ThinkingLabels,
    CommentaryLabels,
    StopSequenceLabels {}
