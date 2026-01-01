import Abstractions
import Database
import Foundation
import OSLog

/// Strategy for canvas management tool.
public struct CanvasStrategy: ToolStrategy {
    private static let logger: Logger = Logger(subsystem: "Tools", category: "CanvasStrategy")

    private let database: DatabaseProtocol

    public let definition: ToolDefinition = ToolDefinition(
        name: "canvas",
        description: """
            Create and update a live canvas document for the current chat. \
            Use action=create to create a new canvas, update to replace content, \
            append to add content, get to fetch, and list to view available canvases.
            """,
        schema: """
        {
            "type": "object",
            "properties": {
                "action": {
                    "type": "string",
                    "enum": ["create", "update", "append", "get", "list"]
                },
                "title": { "type": "string" },
                "content": { "type": "string" },
                "canvas_id": { "type": "string" },
                "chat_id": { "type": "string" }
            },
            "required": ["action"]
        }
        """
    )

    public init(database: DatabaseProtocol) {
        self.database = database
    }

    public func execute(request: ToolRequest) async -> ToolResponse {
        switch BaseToolStrategy.parseArguments(request) {
        case .failure(let error):
            return BaseToolStrategy.errorResponse(request: request, error: error.message)

        case .success(let json):
            guard let action = (json["action"] as? String)?.lowercased() else {
                return BaseToolStrategy.errorResponse(
                    request: request,
                    error: "Missing required parameter: action"
                )
            }

            switch action {
            case "create":
                return await createCanvas(json: json, request: request)
            case "update":
                return await updateCanvas(json: json, request: request, append: false)
            case "append":
                return await updateCanvas(json: json, request: request, append: true)
            case "get":
                return await getCanvas(json: json, request: request)
            case "list":
                return await listCanvases(json: json, request: request)
            default:
                return BaseToolStrategy.errorResponse(
                    request: request,
                    error: "Unsupported action: \(action)"
                )
            }
        }
    }

    private func createCanvas(
        json: [String: Any],
        request: ToolRequest
    ) async -> ToolResponse {
        let title = (json["title"] as? String)?.trimmingCharacters(in: .whitespacesAndNewlines)
            ?? "Canvas"
        let content = json["content"] as? String ?? ""
        let chatId = parseChatId(json["chat_id"], request: request)

        guard let chatId else {
            return BaseToolStrategy.errorResponse(
                request: request,
                error: "Missing chat context for canvas"
            )
        }

        do {
            let canvasId = try await database.write(
                CanvasCommands.Create(title: title, content: content, chatId: chatId)
            )
            return BaseToolStrategy.successResponse(
                request: request,
                result: "Canvas created (\(canvasId.uuidString))"
            )
        } catch {
            Self.logger.error("Failed to create canvas: \(error.localizedDescription)")
            return BaseToolStrategy.errorResponse(
                request: request,
                error: "Failed to create canvas: \(error.localizedDescription)"
            )
        }
    }

    private func updateCanvas(
        json: [String: Any],
        request: ToolRequest,
        append: Bool
    ) async -> ToolResponse {
        guard let content = json["content"] as? String else {
            return BaseToolStrategy.errorResponse(
                request: request,
                error: "Missing required parameter: content"
            )
        }

        do {
            let canvasId = try await resolveCanvasId(json: json, request: request)
            let existing = try await database.read(CanvasCommands.Get(id: canvasId))
            let newContent: String
            if append {
                let separator = existing.content.isEmpty ? "" : "\n"
                newContent = existing.content + separator + content
            } else {
                newContent = content
            }

            _ = try await database.write(
                CanvasCommands.Update(
                    id: canvasId,
                    title: json["title"] as? String,
                    content: newContent
                )
            )
            return BaseToolStrategy.successResponse(
                request: request,
                result: "Canvas updated"
            )
        } catch {
            Self.logger.error("Failed to update canvas: \(error.localizedDescription)")
            return BaseToolStrategy.errorResponse(
                request: request,
                error: "Failed to update canvas: \(error.localizedDescription)"
            )
        }
    }

    private func getCanvas(
        json: [String: Any],
        request: ToolRequest
    ) async -> ToolResponse {
        do {
            let canvasId = try await resolveCanvasId(json: json, request: request)
            let canvas = try await database.read(CanvasCommands.Get(id: canvasId))
            let payload: [String: Any] = [
                "id": canvas.id.uuidString,
                "title": canvas.title,
                "content": canvas.content,
                "updated_at": canvas.updatedAt.iso8601String()
            ]
            return BaseToolStrategy.successResponse(
                request: request,
                result: payload.jsonString() ?? canvas.content
            )
        } catch {
            Self.logger.error("Failed to fetch canvas: \(error.localizedDescription)")
            return BaseToolStrategy.errorResponse(
                request: request,
                error: "Failed to fetch canvas: \(error.localizedDescription)"
            )
        }
    }

    private func listCanvases(
        json: [String: Any],
        request: ToolRequest
    ) async -> ToolResponse {
        do {
            let chatId = parseChatId(json["chat_id"], request: request)
            let canvases = try await database.read(CanvasCommands.List(chatId: chatId))
            let payload: [[String: Any]] = canvases.map { canvas in
                [
                    "id": canvas.id.uuidString,
                    "title": canvas.title,
                    "updated_at": canvas.updatedAt.iso8601String()
                ]
            }
            return BaseToolStrategy.successResponse(
                request: request,
                result: payload.jsonString() ?? "[]"
            )
        } catch {
            Self.logger.error("Failed to list canvases: \(error.localizedDescription)")
            return BaseToolStrategy.errorResponse(
                request: request,
                error: "Failed to list canvases: \(error.localizedDescription)"
            )
        }
    }

    private func resolveCanvasId(
        json: [String: Any],
        request: ToolRequest
    ) async throws -> UUID {
        if let idString = json["canvas_id"] as? String,
           let id = UUID(uuidString: idString) {
            return id
        }

        guard let chatId = parseChatId(json["chat_id"], request: request) else {
            throw DatabaseError.invalidInput("Missing chat for canvas")
        }

        let canvasId = try await database.write(
            CanvasCommands.GetOrCreateDefault(chatId: chatId)
        )
        return canvasId
    }

    private func parseChatId(_ value: Any?, request: ToolRequest) -> UUID? {
        if let value = value as? String, let id = UUID(uuidString: value) {
            return id
        }
        return request.context?.chatId
    }
}

private extension Date {
    func iso8601String() -> String {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return formatter.string(from: self)
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

private extension Array where Element == [String: Any] {
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
