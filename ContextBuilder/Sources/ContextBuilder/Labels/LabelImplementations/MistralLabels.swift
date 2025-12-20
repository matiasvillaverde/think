import Foundation

/// Concrete implementation of Mistral labels
/// Uses [INST] markers for instructions
internal struct MistralLabels: MistralLabelsProtocol {
    // CoreRoleLabels
    let userLabel: String = "[INST] "
    let assistantLabel: String = ""
    let systemLabel: String = ""
    let endLabel: String = " [/INST]"

    // InformationLabels
    let informationLabel: String = "<|information|>"

    // ToolCallingLabels
    let toolLabel: String = "[TOOL] "
    let toolEndLabel: String = " [/TOOL]"
    let toolResponseLabel: String = ""
    let toolResponseEndLabel: String = ""

    // ThinkingLabels
    let thinkingStartLabel: String = "[THINK] "
    let thinkingEndLabel: String = " [/THINK]"

    // CommentaryLabels
    let commentaryStartLabel: String = "<commentary>"
    let commentaryEndLabel: String = "</commentary>"

    // StopSequenceLabels
    var stopSequence: Set<String?> {
        Set(["</s>", "<|im_end|>"])
    }
}
