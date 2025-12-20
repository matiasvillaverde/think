import Foundation

/// Concrete implementation of Harmony labels
/// Used by Harmony and GPT architectures with channel-based formatting
internal struct HarmonyLabels: HarmonyLabelsProtocol {
    // CoreRoleLabels
    let userLabel: String = "<user>"
    let assistantLabel: String = "<assistant>"
    let systemLabel: String = "<system>"
    let endLabel: String = "</end>"

    // InformationLabels
    let informationLabel: String = "<information>"

    // ToolCallingLabels
    let toolLabel: String = "<tool>"
    let toolEndLabel: String = "</tool>"
    let toolResponseLabel: String = "<tool_response>"
    let toolResponseEndLabel: String = "</tool_response>"

    // ThinkingLabels
    let thinkingStartLabel: String = "<thinking>"
    let thinkingEndLabel: String = "</thinking>"

    // CommentaryLabels
    let commentaryStartLabel: String = "<commentary>"
    let commentaryEndLabel: String = "</commentary>"

    // HarmonyTokenLabels
    let startToken: String? = "<start>"
    let messageToken: String? = "<message>"
    let channelToken: String? = "<channel>"
    let callToken: String? = "<call>"
    let returnToken: String? = "<return>"
    let constrainToken: String? = "<constrain>"

    // HarmonyChannelLabels
    let analysisChannel: String? = "analysis"
    let finalChannel: String? = "final"
    let commentaryChannel: String? = "commentary"
    let developerLabel: String? = "<developer>"

    // StopSequenceLabels
    var stopSequence: Set<String?> {
        Set([endLabel, "</message>"])
    }
}
