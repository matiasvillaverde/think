import Abstractions
import Database
import Foundation
import OSLog

/// Strategy for node status tool.
public struct NodesStrategy: ToolStrategy {
    private static let logger: Logger = Logger(subsystem: "Tools", category: "NodesStrategy")

    private let database: DatabaseProtocol

    public let definition: ToolDefinition = ToolDefinition(
        name: "nodes",
        description: "Report local node mode settings and availability.",
        schema: """
        {
            "type": "object",
            "properties": {}
        }
        """
    )

    public init(database: DatabaseProtocol) {
        self.database = database
    }

    public func execute(request: ToolRequest) async -> ToolResponse {
        do {
            let settings = try await database.read(SettingsCommands.GetOrCreate())
            let payload: [String: Any] = [
                "enabled": settings.nodeModeEnabled,
                "port": settings.nodeModePort,
                "auth_required": settings.nodeModeAuthToken != nil
            ]
            return BaseToolStrategy.successResponse(
                request: request,
                result: payload.jsonString() ?? "Node mode status"
            )
        } catch {
            Self.logger.error("Failed to read node settings: \(error.localizedDescription)")
            return BaseToolStrategy.errorResponse(
                request: request,
                error: "Failed to read node settings: \(error.localizedDescription)"
            )
        }
    }
}

private extension Dictionary where Key == String, Value == Any {
    func jsonString() -> String? {
        guard JSONSerialization.isValidJSONObject(self) else {
            return nil
        }
        guard let data = try? JSONSerialization.data(withJSONObject: self, options: []) else {
            return nil
        }
        return String(data: data, encoding: .utf8)
    }
}
