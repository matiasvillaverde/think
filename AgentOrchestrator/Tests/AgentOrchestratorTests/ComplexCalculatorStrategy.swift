import Abstractions
import Tools

internal final class ComplexCalculatorStrategy: ToolStrategy {
    internal let definition: ToolDefinition = ToolDefinition(
        name: "calculator",
        description: "Perform calculations",
        schema: """
        {
            "type": "object",
            "properties": {
                "operation": { "type": "string" }
            },
            "required": ["operation"]
        }
        """
    )

    internal func execute(request: ToolRequest) -> ToolResponse {
        ToolResponse(
            requestId: request.id,
            toolName: "calculator",
            result: """
            {
                "result": 630
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
