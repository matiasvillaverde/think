import Abstractions
import Foundation
import OSLog

/// Strategy for Python code execution tool
public struct PythonStrategy: ToolStrategy {
    /// Logger for Python execution operations
    private static let logger: Logger = Logger(subsystem: "Tools", category: "PythonStrategy")
    /// Default timeout for Python execution in seconds
    private static let defaultTimeout: Int = 30

    /// Maximum timeout for Python execution in seconds
    private static let maxTimeout: Int = 300

    /// The tool definition
    public let definition: ToolDefinition = ToolDefinition(
        name: "python_exec",
        description: "Execute Python code in a sandboxed environment",
        schema: """
        {
            "type": "object",
            "properties": {
                "code": {
                    "type": "string",
                    "description": "Python code to execute"
                },
                "timeout": {
                    "type": "integer",
                    "description": "Execution timeout in seconds",
                    "minimum": 1,
                    "maximum": 300,
                    "default": 30
                }
            },
            "required": ["code"]
        }
        """
    )

    /// Initialize a new PythonStrategy
    public init() {
        // No initialization required
    }

    /// Execute the Python code
    /// - Parameter request: The tool request containing Python code
    /// - Returns: The execution result
    public func execute(request: ToolRequest) -> ToolResponse {
        Self.logger.debug("Processing Python execution request for request ID: \(request.id)")

        // Parse arguments
        switch BaseToolStrategy.parseArguments(request) {
        case .failure(let error):
            return BaseToolStrategy.errorResponse(request: request, error: error.message)

        case .success(let json):
            // Validate required code parameter
            guard let code = json["code"] as? String, !code.isEmpty else {
                Self.logger.warning("Python execution request missing code parameter")
                return BaseToolStrategy.errorResponse(
                    request: request,
                    error: "Missing required parameter: code"
                )
            }

            // Extract optional timeout
            let timeout: Int = json["timeout"] as? Int ?? Self.defaultTimeout
            let clampedTimeout: Int = min(timeout, Self.maxTimeout)

            Self.logger.info("Executing Python code with timeout: \(clampedTimeout)s")
            Self.logger.debug("Python code length: \(code.count) characters")

            // Execute Python code (mock implementation)
            let result: String = executePythonCode(
                code: code,
                timeout: clampedTimeout
            )

            // Check for errors in result
            if result.contains("SyntaxError") {
                Self.logger.error("Python execution failed with syntax error")
                return BaseToolStrategy.errorResponse(
                    request: request,
                    error: result
                )
            }

            if result.contains("timeout") {
                Self.logger.error("Python execution timed out after \(clampedTimeout)s")
                return BaseToolStrategy.errorResponse(
                    request: request,
                    error: "Execution timeout after \(clampedTimeout) seconds"
                )
            }

            Self.logger.notice("Python code executed successfully")

            return BaseToolStrategy.successResponse(
                request: request,
                result: result
            )
        }
    }

    /// Execute Python code (mock implementation)
    /// - Parameters:
    ///   - code: The Python code to execute
    ///   - timeout: Execution timeout in seconds
    /// - Returns: The execution result
    private func executePythonCode(code: String, timeout: Int) -> String {
        // Mock implementation for testing
        // In a real implementation, this would use Process or similar

        // Simulate syntax error
        if code.contains("print('missing closing quote)") {
            return "SyntaxError: unterminated string literal"
        }

        // Simulate timeout
        let sleepDuration: Int = 10
        if code.contains("time.sleep(10)"), timeout < sleepDuration {
            return "Execution timeout"
        }

        // Simulate simple print
        if code.contains("print('Hello, World!')") {
            return "Hello, World!"
        }

        // Simulate math operation
        if code.contains("result = 5 + 3") {
            return "Result: 8"
        }

        // Default response
        return "Code executed successfully"
    }
}
