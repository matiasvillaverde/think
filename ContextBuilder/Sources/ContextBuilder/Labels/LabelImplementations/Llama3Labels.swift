import Foundation

/// Concrete implementation of Llama 3 labels
internal struct Llama3Labels: Llama3LabelsProtocol {
    // CoreRoleLabels
    let userLabel: String = "<|start_header_id|>user<|end_header_id|>\n\n"
    let assistantLabel: String = "<|start_header_id|>assistant<|end_header_id|>\n\n"
    let systemLabel: String = "<|start_header_id|>system<|end_header_id|>\n\n"
    let endLabel: String = "<|eot_id|>"

    // InformationLabels
    let informationLabel: String = "<|information|>"

    // ToolCallingLabels
    let toolLabel: String = "<|start_header_id|>tool<|end_header_id|>\n\n"
    let toolEndLabel: String = "<|eot_id|>"
    let toolResponseLabel: String = "<tool_response>"
    let toolResponseEndLabel: String = "</tool_response>"

    // PythonEnvironmentLabels (Llama 3.1 specific)
    let pythonTagLabel: String? = "<|python_tag|>"
    let endOfMessageLabel: String? = "<|eom_id|>"
    let ipythonLabel: String? = "<|start_header_id|>ipython<|end_header_id|>\n\n"

    // StopSequenceLabels
    var stopSequence: Set<String?> {
        Set([endLabel, "<|eot_id|>"])
    }
}
