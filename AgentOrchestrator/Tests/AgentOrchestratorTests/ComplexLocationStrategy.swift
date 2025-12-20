import Abstractions
import Tools

internal final class ComplexLocationStrategy: ToolStrategy {
    internal let definition: ToolDefinition = ToolDefinition(
        name: "location",
        description: "Search for places",
        schema: """
        {
            "type": "object",
            "properties": {
                "query": { "type": "string" }
            },
            "required": ["query"]
        }
        """
    )

    internal func execute(request: ToolRequest) -> ToolResponse {
        ToolResponse(
            requestId: request.id,
            toolName: "location",
            result: """
            {
                "places": ["Louvre", "Eiffel Tower"]
            }
            """,
            metadata: nil,
            error: nil
        )
    }

    internal init() {
        // No initialization needed
    }

    deinit {
        // No cleanup needed
    }
}
