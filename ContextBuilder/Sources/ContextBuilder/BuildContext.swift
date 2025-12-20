import Abstractions
import Foundation

/// Context for building formatted output - groups parameters to avoid excessive parameter count
internal struct BuildContext {
    let action: Action
    let contextConfiguration: ContextConfiguration
    let toolResponses: [ToolResponse]
    let toolDefinitions: [ToolDefinition]
}
