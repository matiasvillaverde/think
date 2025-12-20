import Abstractions
import Tools

internal final class ComplexWeatherStrategy: ToolStrategy {
    internal let definition: ToolDefinition = ToolDefinition(
        name: "weather",
        description: "Get weather forecast",
        schema: """
        {
            "type": "object",
            "properties": {
                "location": { "type": "string" }
            },
            "required": ["location"]
        }
        """
    )

    internal func execute(request: ToolRequest) -> ToolResponse {
        ToolResponse(
            requestId: request.id,
            toolName: "weather",
            result: """
            {
                "forecast": "Sunny, 22°C"
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
