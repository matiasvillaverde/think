import Abstractions
import Database
import Foundation
import OSLog

/// Strategy for node status tool.
public struct NodesStrategy: ToolStrategy {
    private static let logger: Logger = Logger(subsystem: "Tools", category: "NodesStrategy")

    private let database: DatabaseProtocol

    private struct NodeSettingsSnapshot: Sendable {
        let enabled: Bool
        let port: Int
        let authRequired: Bool
    }

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
            let settings: NodeSettingsSnapshot = try await fetchSettingsSnapshot()
            let payload: [String: Any] = [
                "enabled": settings.enabled,
                "port": settings.port,
                "auth_required": settings.authRequired
            ]
            return BaseToolStrategy.successResponse(
                request: request,
                result: jsonString(from: payload) ?? "Node mode status"
            )
        } catch {
            Self.logger.error("Failed to read node settings: \(error.localizedDescription)")
            return BaseToolStrategy.errorResponse(
                request: request,
                error: "Failed to read node settings: \(error.localizedDescription)"
            )
        }
    }

    private func jsonString(from payload: [String: Any]) -> String? {
        guard JSONSerialization.isValidJSONObject(payload) else {
            return nil
        }
        guard let data: Data = try? JSONSerialization.data(withJSONObject: payload, options: []) else {
            return nil
        }
        return String(data: data, encoding: .utf8)
    }

    @MainActor
    private func fetchSettingsSnapshot() async throws -> NodeSettingsSnapshot {
        let settings: AppSettings = try await database.read(SettingsCommands.GetOrCreate())
        return NodeSettingsSnapshot(
            enabled: settings.nodeModeEnabled,
            port: settings.nodeModePort,
            authRequired: settings.nodeModeAuthToken != nil
        )
    }
}
