import Abstractions
import Foundation
import os

/// Base implementation for common tool strategy functionality
/// Using enum to prevent instantiation (convenience type pattern)
public enum BaseToolStrategy {
    private static let logger: Logger = Logger(subsystem: "Tools", category: "BaseToolStrategy")
    /// Parse JSON arguments from request
    /// - Parameter request: The tool request containing arguments
    /// - Returns: Parsed JSON dictionary or error
    public static func parseArguments(_ request: ToolRequest) -> Result<[String: Any], ToolError> {
        logger.debug("Parsing arguments for tool request: \(request.name, privacy: .public)")
        guard let data = request.arguments.data(using: .utf8) else {
            logger.error("Invalid UTF-8 encoding in arguments for tool: \(request.name, privacy: .public)")
            return .failure(ToolError("Invalid UTF-8 in arguments"))
        }

        do {
            if let json = try JSONSerialization.jsonObject(with: data) as? [String: Any] {
                logger.debug("Successfully parsed arguments for tool: \(request.name, privacy: .public)")
                return .success(json)
            }
            logger.error("Arguments are not a JSON object for tool: \(request.name, privacy: .public)")
            return .failure(ToolError("Arguments must be a JSON object"))
        } catch {
            logger.error(
                "JSON parsing failed for tool \(request.name, privacy: .public): \(error.localizedDescription)"
            )
            return .failure(ToolError("Invalid JSON: \(error.localizedDescription)"))
        }
    }

    /// Create an error response
    /// - Parameters:
    ///   - request: The original tool request
    ///   - error: The error message
    /// - Returns: A tool response with error
    public static func errorResponse(
        request: ToolRequest,
        error: String
    ) -> ToolResponse {
        ToolResponse(
            requestId: request.id,
            toolName: request.name,
            result: "",
            error: error
        )
    }

    /// Create a success response
    /// - Parameters:
    ///   - request: The original tool request
    ///   - result: The successful result string
    /// - Returns: A tool response with result
    public static func successResponse(
        request: ToolRequest,
        result: String
    ) -> ToolResponse {
        ToolResponse(
            requestId: request.id,
            toolName: request.name,
            result: result
        )
    }
}
