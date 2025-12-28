import Abstractions
import Foundation

/// Formatter for Harmony/GPT architectures with channel-based formatting
internal struct HarmonyContextFormatter:
    ContextFormatter,
    DateFormatting,
    MemoryFormatting,
    SkillFormatting,
    WorkspaceFormatting {
    internal let labels: HarmonyLabels

    // Pre-allocation constants to avoid magic numbers
    internal static let respMult: Int = 4
    internal static let buildComps: Int = 4
    internal static let sysComps: Int = 2
    internal static let convMult: Int = 2
    internal static let sysMsgParts: Int = 10
    internal static let toolMult: Int = 3
    internal static let devComps: Int = 4
    internal static let chanComps: Int = 2
}
