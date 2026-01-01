import Abstractions
import Database
import Foundation
import OSLog

/// Strategy for cron scheduling tool.
public struct CronStrategy: ToolStrategy {
    private static let logger: Logger = Logger(subsystem: "Tools", category: "CronStrategy")

    private let database: DatabaseProtocol

    public let definition: ToolDefinition = ToolDefinition(
        name: "cron",
        description: """
            Schedule prompts to run in the future. Use action=create to create a schedule \
            with a cron expression, list to view schedules, enable/disable to toggle, and delete \
            to remove schedules. Cron format: "min hour day month weekday".
            """,
        schema: """
        {
            "type": "object",
            "properties": {
                "action": {
                    "type": "string",
                    "enum": ["create", "list", "enable", "disable", "delete", "update"]
                },
                "title": { "type": "string" },
                "prompt": { "type": "string" },
                "cron": {
                    "type": "string",
                    "description": "Cron expression or ISO 8601 date for one-shot schedules"
                },
                "schedule_kind": {
                    "type": "string",
                    "enum": ["cron", "one_shot"],
                    "default": "cron"
                },
                "action_type": {
                    "type": "string",
                    "enum": ["text", "image"],
                    "default": "text"
                },
                "timezone": { "type": "string" },
                "tools": {
                    "type": "array",
                    "items": { "type": "string" },
                    "default": []
                },
                "schedule_id": { "type": "string" },
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
                return await createSchedule(json: json, request: request)

            case "list":
                return await listSchedules(json: json, request: request)

            case "enable":
                return await setScheduleEnabled(json: json, request: request, enabled: true)

            case "disable":
                return await setScheduleEnabled(json: json, request: request, enabled: false)

            case "delete":
                return await deleteSchedule(json: json, request: request)

            case "update":
                return await updateSchedule(json: json, request: request)

            default:
                return BaseToolStrategy.errorResponse(
                    request: request,
                    error: "Unsupported action: \(action)"
                )
            }
        }
    }

    private struct CreateScheduleInput {
        let title: String
        let prompt: String
        let scheduleKind: AutomationScheduleKind
        let actionType: AutomationActionType
        let cronExpression: String
        let timezoneIdentifier: String?
        let toolNames: [String]
        let chatId: UUID?
    }

    private func buildCreateInput(
        json: [String: Any],
        request: ToolRequest,
        prompt: String,
        cron: String
    ) -> CreateScheduleInput {
        let title: String? = (json["title"] as? String)?.trimmingCharacters(in: .whitespacesAndNewlines)
        let scheduleKind: AutomationScheduleKind = parseScheduleKind(json["schedule_kind"] as? String)
        let actionType: AutomationActionType = parseActionType(json["action_type"] as? String)
        let timezone: String? = json["timezone"] as? String
        let tools: [String] = json["tools"] as? [String] ?? []
        let chatId: UUID? = parseChatId(json["chat_id"], request: request)
        let resolvedTitle: String = {
            if let title, !title.isEmpty {
                return title
            }
            return "Scheduled Task"
        }()

        return CreateScheduleInput(
            title: resolvedTitle,
            prompt: prompt,
            scheduleKind: scheduleKind,
            actionType: actionType,
            cronExpression: cron,
            timezoneIdentifier: timezone,
            toolNames: tools,
            chatId: chatId
        )
    }

    private func createSchedule(
        json: [String: Any],
        request: ToolRequest
    ) async -> ToolResponse {
        guard let prompt = json["prompt"] as? String, !prompt.isEmpty else {
            return BaseToolStrategy.errorResponse(
                request: request,
                error: "Missing required parameter: prompt"
            )
        }
        guard let cron = json["cron"] as? String, !cron.isEmpty else {
            return BaseToolStrategy.errorResponse(
                request: request,
                error: "Missing required parameter: cron"
            )
        }

        let input: CreateScheduleInput = buildCreateInput(
            json: json,
            request: request,
            prompt: prompt,
            cron: cron
        )

        do {
            let payload: [String: Any] = try await createSchedulePayload(input: input)
            let scheduleId: String = payload["id"] as? String ?? ""
            let fallbackResult: String = scheduleId.isEmpty ? "Schedule created" : "Scheduled \(scheduleId)"
            return BaseToolStrategy.successResponse(
                request: request,
                result: jsonString(from: payload) ?? fallbackResult
            )
        } catch {
            Self.logger.error("Failed to create schedule: \(error.localizedDescription)")
            return BaseToolStrategy.errorResponse(
                request: request,
                error: "Failed to create schedule: \(error.localizedDescription)"
            )
        }
    }

    private func createSchedulePayload(
        input: CreateScheduleInput
    ) async throws -> [String: Any] {
        let scheduleId: UUID = try await database.write(
            AutomationScheduleCommands.Create(
                title: input.title,
                prompt: input.prompt,
                scheduleKind: input.scheduleKind,
                actionType: input.actionType,
                cronExpression: input.cronExpression,
                timezoneIdentifier: input.timezoneIdentifier,
                toolNames: input.toolNames,
                isEnabled: true,
                chatId: input.chatId
            )
        )

        let schedule: AutomationSchedule = try await database.read(
            AutomationScheduleCommands.Get(id: scheduleId)
        )
        let nextRunAt: String = schedule.nextRunAt.map { iso8601String(from: $0) } ?? ""
        return [
            "id": scheduleId.uuidString,
            "next_run_at": nextRunAt
        ]
    }

    private func listSchedules(
        json: [String: Any],
        request: ToolRequest
    ) async -> ToolResponse {
        do {
            let chatId: UUID? = parseChatId(json["chat_id"], request: request)
            let schedules: [AutomationSchedule] = try await database.read(
                AutomationScheduleCommands.List(chatId: chatId)
            )

            let payload: [[String: Any]] = schedules.map { schedule in
                let nextRunAt: String = schedule.nextRunAt.map { iso8601String(from: $0) } ?? ""
                [
                    "id": schedule.id.uuidString,
                    "title": schedule.title,
                    "enabled": schedule.isEnabled,
                    "running": schedule.isRunning,
                    "next_run_at": nextRunAt,
                    "action_type": schedule.actionType.rawValue
                ]
            }

            return BaseToolStrategy.successResponse(
                request: request,
                result: jsonString(from: payload) ?? "[]"
            )
        } catch {
            Self.logger.error("Failed to list schedules: \(error.localizedDescription)")
            return BaseToolStrategy.errorResponse(
                request: request,
                error: "Failed to list schedules: \(error.localizedDescription)"
            )
        }
    }

    private func setScheduleEnabled(
        json: [String: Any],
        request: ToolRequest,
        enabled: Bool
    ) async -> ToolResponse {
        guard let scheduleId: UUID = parseScheduleId(json["schedule_id"]) else {
            return BaseToolStrategy.errorResponse(
                request: request,
                error: "Missing required parameter: schedule_id"
            )
        }

        do {
            _ = try await database.write(
                AutomationScheduleCommands.SetEnabled(id: scheduleId, isEnabled: enabled)
            )
            return BaseToolStrategy.successResponse(
                request: request,
                result: "Schedule \(enabled ? "enabled" : "disabled")"
            )
        } catch {
            Self.logger.error("Failed to update schedule: \(error.localizedDescription)")
            return BaseToolStrategy.errorResponse(
                request: request,
                error: "Failed to update schedule: \(error.localizedDescription)"
            )
        }
    }

    private func updateSchedule(
        json: [String: Any],
        request: ToolRequest
    ) async -> ToolResponse {
        guard let scheduleId: UUID = parseScheduleId(json["schedule_id"]) else {
            return BaseToolStrategy.errorResponse(
                request: request,
                error: "Missing required parameter: schedule_id"
            )
        }

        do {
            _ = try await database.write(
                AutomationScheduleCommands.Update(
                    id: scheduleId,
                    title: json["title"] as? String,
                    prompt: json["prompt"] as? String,
                    cronExpression: json["cron"] as? String,
                    timezoneIdentifier: json["timezone"] as? String,
                    toolNames: json["tools"] as? [String],
                    actionType: parseOptionalActionType(json["action_type"] as? String),
                    scheduleKind: parseOptionalScheduleKind(json["schedule_kind"] as? String)
                )
            )
            return BaseToolStrategy.successResponse(
                request: request,
                result: "Schedule updated"
            )
        } catch {
            Self.logger.error("Failed to update schedule: \(error.localizedDescription)")
            return BaseToolStrategy.errorResponse(
                request: request,
                error: "Failed to update schedule: \(error.localizedDescription)"
            )
        }
    }

    private func deleteSchedule(
        json: [String: Any],
        request: ToolRequest
    ) async -> ToolResponse {
        guard let scheduleId: UUID = parseScheduleId(json["schedule_id"]) else {
            return BaseToolStrategy.errorResponse(
                request: request,
                error: "Missing required parameter: schedule_id"
            )
        }

        do {
            _ = try await database.write(
                AutomationScheduleCommands.Delete(id: scheduleId)
            )
            return BaseToolStrategy.successResponse(
                request: request,
                result: "Schedule deleted"
            )
        } catch {
            Self.logger.error("Failed to delete schedule: \(error.localizedDescription)")
            return BaseToolStrategy.errorResponse(
                request: request,
                error: "Failed to delete schedule: \(error.localizedDescription)"
            )
        }
    }

    private func parseScheduleKind(_ value: String?) -> AutomationScheduleKind {
        switch value?.lowercased() {
        case "one_shot", "oneshot":
            return .oneShot

        default:
            return .cron
        }
    }

    private func parseOptionalScheduleKind(_ value: String?) -> AutomationScheduleKind? {
        guard let value else {
            return nil
        }
        return parseScheduleKind(value)
    }

    private func parseActionType(_ value: String?) -> AutomationActionType {
        switch value?.lowercased() {
        case "image":
            return .image

        default:
            return .text
        }
    }

    private func parseOptionalActionType(_ value: String?) -> AutomationActionType? {
        guard let value else {
            return nil
        }
        return parseActionType(value)
    }

    private func parseChatId(_ value: Any?, request: ToolRequest) -> UUID? {
        if let value = value as? String, let id = UUID(uuidString: value) {
            return id
        }
        return request.context?.chatId
    }

    private func parseScheduleId(_ value: Any?) -> UUID? {
        guard let string = value as? String else {
            return nil
        }
        return UUID(uuidString: string)
    }
    private func iso8601String(from date: Date) -> String {
        let formatter: ISO8601DateFormatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return formatter.string(from: date)
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

    private func jsonString(from payload: [[String: Any]]) -> String? {
        guard JSONSerialization.isValidJSONObject(payload) else {
            return nil
        }
        guard let data: Data = try? JSONSerialization.data(withJSONObject: payload, options: []) else {
            return nil
        }
        return String(data: data, encoding: .utf8)
    }
}
