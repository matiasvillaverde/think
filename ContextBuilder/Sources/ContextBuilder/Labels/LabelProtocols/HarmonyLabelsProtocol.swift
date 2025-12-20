import Foundation

/// Composite protocol for Harmony-style models
/// Includes all ChatML features plus Harmony-specific tokens and channels
internal protocol HarmonyLabelsProtocol: CoreRoleLabels,
    InformationLabels,
    ToolCallingLabels,
    ThinkingLabels,
    CommentaryLabels,
    HarmonyTokenLabels,
    HarmonyChannelLabels,
    StopSequenceLabels {}
