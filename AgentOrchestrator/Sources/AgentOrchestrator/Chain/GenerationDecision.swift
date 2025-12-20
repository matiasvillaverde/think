import Abstractions

internal enum GenerationDecision {
    case complete
    case continueWithNewPrompt(String)
    case error(Error)
    case executeTools([ToolRequest])
}
