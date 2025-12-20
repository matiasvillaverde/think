import Abstractions

internal enum StreamAction {
    case accumulate  // Continue accumulating tokens
    case immediateUpdate(ProcessedOutput)  // Update DB immediately
    case skip  // Skip this chunk
}
