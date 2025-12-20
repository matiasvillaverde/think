import Abstractions
import Foundation
import os

/// Strategy for function execution tool
public struct FunctionsStrategy: ToolStrategy {
    private static let logger: Logger = Logger(subsystem: "Tools", category: "FunctionsStrategy")
    /// Available functions registry
    private static let availableFunctions: [String: String] = [
        "calculate_sum": "Calculates the sum of two numbers",
        "get_timestamp": "Returns the current timestamp",
        "list_functions": "Lists all available functions",
        "string_concat": "Concatenates two strings",
        "calculate_product": "Calculates the product of two numbers"
    ]

    /// The tool definition
    public let definition: ToolDefinition = ToolDefinition(
        name: "functions",
        description: "Execute predefined functions with optional parameters",
        schema: """
        {
            "type": "object",
            "properties": {
                "function_name": {
                    "type": "string",
                    "description": "Name of the function to execute"
                },
                "parameters": {
                    "type": "object",
                    "description": "Optional parameters for the function"
                }
            },
            "required": ["function_name"]
        }
        """
    )

    /// Initialize a new FunctionsStrategy
    public init() {
        Self.logger.debug("Initializing FunctionsStrategy with \(Self.availableFunctions.count) functions")
    }

    /// Execute the function request
    /// - Parameter request: The tool request
    /// - Returns: The tool response with function result
    public func execute(request: ToolRequest) -> ToolResponse {
        // Parse arguments
        switch BaseToolStrategy.parseArguments(request) {
        case .failure(let error):
            return BaseToolStrategy.errorResponse(request: request, error: error.message)

        case .success(let json):
            // Validate required function_name parameter
            guard let functionName = json["function_name"] as? String else {
                return BaseToolStrategy.errorResponse(
                    request: request,
                    error: "Missing required parameter: function_name"
                )
            }

            // Extract optional parameters
            let parameters: [String: Any] = json["parameters"] as? [String: Any] ?? [:]

            // Execute the function
            Self.logger.info("Executing function: \(functionName, privacy: .public)")
            let result: String = executeFunction(
                name: functionName,
                parameters: parameters
            )

            // Check if it's an error
            if result.hasPrefix("Error:") {
                Self.logger.warning("Function execution failed: \(functionName, privacy: .public)")
                return BaseToolStrategy.errorResponse(
                    request: request,
                    error: result
                )
            }

            Self.logger.debug("Function executed successfully: \(functionName, privacy: .public)")
            return BaseToolStrategy.successResponse(
                request: request,
                result: result
            )
        }
    }

    /// Execute a specific function
    /// - Parameters:
    ///   - name: The function name
    ///   - parameters: The function parameters
    /// - Returns: The function result or error message
    private func executeFunction(name: String, parameters: [String: Any]) -> String {
        switch name {
        case "calculate_sum":
            return calculateSum(parameters: parameters)

        case "get_timestamp":
            return getTimestamp()

        case "list_functions":
            return listFunctions()

        case "string_concat":
            return stringConcat(parameters: parameters)

        case "calculate_product":
            return calculateProduct(parameters: parameters)

        default:
            return "Error: Unknown function: \(name)"
        }
    }

    /// Calculate sum of two numbers
    private func calculateSum(parameters: [String: Any]) -> String {
        guard let aValue = parameters["a"] as? Int,
            let bValue = parameters["b"] as? Int else {
            return "Error: calculate_sum requires parameters 'a' and 'b' as integers"
        }

        let sum: Int = aValue + bValue
        return "Result: \(sum)"
    }

    /// Get current timestamp
    private func getTimestamp() -> String {
        let timestamp: Date = Date()
        let formatter: ISO8601DateFormatter = ISO8601DateFormatter()
        return "Current timestamp: \(formatter.string(from: timestamp))"
    }

    /// List available functions
    private func listFunctions() -> String {
        var result: String = "Available functions:\n"
        for (functionName, description) in Self.availableFunctions {
            result += "- \(functionName): \(description)\n"
        }
        return result
    }

    /// Concatenate two strings
    private func stringConcat(parameters: [String: Any]) -> String {
        guard let str1 = parameters["str1"] as? String,
            let str2 = parameters["str2"] as? String else {
            return "Error: string_concat requires parameters 'str1' and 'str2' as strings"
        }

        return "Result: \(str1)\(str2)"
    }

    /// Calculate product of two numbers
    private func calculateProduct(parameters: [String: Any]) -> String {
        guard let aValue = parameters["a"] as? Int,
            let bValue = parameters["b"] as? Int else {
            return "Error: calculate_product requires parameters 'a' and 'b' as integers"
        }

        let product: Int = aValue * bValue
        return "Result: \(product)"
    }
}
