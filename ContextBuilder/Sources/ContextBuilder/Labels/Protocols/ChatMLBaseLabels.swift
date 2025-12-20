import Foundation

/// Base protocol for ChatML-style models with default implementations
/// Provides common ChatML label values used by multiple models
internal protocol ChatMLBaseLabels: CoreRoleLabels,
    InformationLabels,
    ToolCallingLabels,
    ThinkingLabels,
    CommentaryLabels,
    StopSequenceLabels,
    ToolInstructions {}

// MARK: - Default ChatML Implementations

extension ChatMLBaseLabels {
    // MARK: CoreRoleLabels Defaults
    var userLabel: String { "<|im_start|>user\n" }
    var assistantLabel: String { "<|im_start|>assistant\n" }
    var systemLabel: String { "<|im_start|>system\n" }
    var endLabel: String { "<|im_end|>" }

    // MARK: InformationLabels Defaults
    var informationLabel: String { "<|information|>" }

    // MARK: ToolCallingLabels Defaults
    var toolLabel: String { "<|im_start|>tool\n" }
    var toolEndLabel: String { "<|im_end|>" }
    var toolResponseLabel: String { "<tool_response>" }
    var toolResponseEndLabel: String { "</tool_response>" }

    // MARK: ThinkingLabels Defaults
    var thinkingStartLabel: String { "<think>" }
    var thinkingEndLabel: String { "</think>" }

    // MARK: CommentaryLabels Defaults
    var commentaryStartLabel: String { "<commentary>" }
    var commentaryEndLabel: String { "</commentary>" }

    // MARK: StopSequenceLabels Defaults
    var stopSequence: Set<String?> {
        Set([endLabel])
    }

    // MARK: ToolInstructions Defaults
    var toolSectionTitle: String {
        "# Tools Available"
    }

    var toolIntroduction: String {
        """
        You are provided with function signatures within <tools></tools> XML tags. \
        You may call one or more functions to assist with the user query. \
        Don't make assumptions about what values to plug into functions.
        """
    }

    var toolCallInstructions: String {
        """
        # How to Call Functions
        Before calling any function, provide your reasoning in <commentary></commentary> tags.
        Then, for each function call, return a JSON object with function name and arguments within \
        <tool_call></tool_call> XML tags:

        <commentary>
        Explain your reasoning for using the tool here
        </commentary>
        <tool_call>
        {"name": "<function-name>", "arguments": <args-dict>}
        </tool_call>
        """
    }

    var toolImportantInstructions: [String] {
        [
            "Only call functions when necessary to answer the user's query",
            "Always write commentary before making tool calls to explain your reasoning",
            "You can make multiple function calls if needed",
            "Wait for function results before providing your final answer",
            "If you don't need any functions to answer the query, respond normally"
        ]
    }

    var useArrayFormat: Bool {
        true
    }
}
