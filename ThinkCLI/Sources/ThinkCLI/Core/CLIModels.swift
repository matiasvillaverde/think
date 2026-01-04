import Abstractions
import Database
import Foundation

struct ModelSummary: Codable, Sendable, Equatable {
    let id: UUID
    let location: String
    let backend: String
    let type: String
    let locationKind: String
    let ramNeeded: UInt64
    let architecture: String
    let locationLocal: String?

    init(model: SendableModel) {
        id = model.id
        location = model.location
        backend = model.backend.rawValue
        type = model.modelType.rawValue
        locationKind = model.locationKind.rawValue
        ramNeeded = model.ramNeeded
        architecture = model.architecture.rawValue
        locationLocal = model.locationLocal
    }
}

struct ToolDefinitionSummary: Codable, Sendable, Equatable {
    let id: UUID
    let name: String
    let description: String
    let schema: String

    init(definition: ToolDefinition) {
        id = definition.id
        name = definition.name
        description = definition.description
        schema = definition.schema
    }
}

struct SkillSummary: Codable, Sendable, Equatable {
    let id: UUID
    let name: String
    let isEnabled: Bool
    let tools: [String]
    let chatId: UUID?

    init(skill: Skill) {
        id = skill.id
        name = skill.name
        isEnabled = skill.isEnabled
        tools = skill.tools
        chatId = skill.chat?.id
    }
}

struct ScheduleSummary: Codable, Sendable, Equatable {
    let id: UUID
    let title: String
    let prompt: String
    let kind: String
    let actionType: String
    let cronExpression: String
    let timezoneIdentifier: String?
    let toolNames: [String]
    let isEnabled: Bool
    let chatId: UUID?
    let nextRunAt: Date?
    let lastRunAt: Date?

    init(schedule: AutomationSchedule) {
        id = schedule.id
        title = schedule.title
        prompt = schedule.prompt
        kind = schedule.scheduleKind.rawValue
        actionType = schedule.actionType.rawValue
        cronExpression = schedule.cronExpression
        timezoneIdentifier = schedule.timezoneIdentifier
        toolNames = schedule.toolNames
        isEnabled = schedule.isEnabled
        chatId = schedule.chat?.id
        nextRunAt = schedule.nextRunAt
        lastRunAt = schedule.lastRunAt
    }
}

struct RagSearchResultSummary: Codable, Sendable, Equatable {
    let id: UUID
    let score: Double
    let text: String
    let keywords: String
    let rowId: UInt

    init(result: SearchResult) {
        id = result.id
        score = result.score
        text = result.text
        keywords = result.keywords
        rowId = result.rowId
    }
}
