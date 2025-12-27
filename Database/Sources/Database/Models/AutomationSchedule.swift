import Abstractions
import Foundation
import SwiftData

@Model
@DebugDescription
public final class AutomationSchedule: Identifiable, Equatable {
    // MARK: - Identity

    @Attribute(.unique)
    public private(set) var id: UUID = UUID()

    @Attribute()
    public private(set) var createdAt: Date = Date()

    @Attribute()
    public internal(set) var updatedAt: Date = Date()

    // MARK: - Configuration

    @Attribute()
    public internal(set) var title: String

    @Attribute()
    public internal(set) var prompt: String

    @Attribute()
    public internal(set) var scheduleKindRaw: String

    @Attribute()
    public internal(set) var actionTypeRaw: String

    @Attribute()
    public internal(set) var cronExpression: String

    @Attribute()
    public internal(set) var timezoneIdentifier: String?

    @Attribute()
    public internal(set) var toolNames: [String] = []

    // MARK: - State

    @Attribute()
    public internal(set) var isEnabled: Bool = true

    @Attribute()
    public internal(set) var isRunning: Bool = false

    @Attribute()
    public internal(set) var lastRunAt: Date?

    @Attribute()
    public internal(set) var nextRunAt: Date?

    // MARK: - Relationships

    @Relationship(deleteRule: .nullify)
    public private(set) var chat: Chat?

    // MARK: - Initializer

    init(
        title: String,
        prompt: String,
        scheduleKind: AutomationScheduleKind,
        actionType: AutomationActionType,
        cronExpression: String,
        timezoneIdentifier: String? = nil,
        toolNames: [String] = [],
        isEnabled: Bool = true,
        chat: Chat?
    ) {
        self.title = title
        self.prompt = prompt
        self.scheduleKindRaw = scheduleKind.rawValue
        self.actionTypeRaw = actionType.rawValue
        self.cronExpression = cronExpression
        self.timezoneIdentifier = timezoneIdentifier
        self.toolNames = toolNames
        self.isEnabled = isEnabled
        self.chat = chat
    }
}

extension AutomationSchedule {
    public var scheduleKind: AutomationScheduleKind {
        get { AutomationScheduleKind(rawValue: scheduleKindRaw) ?? .cron }
        set { scheduleKindRaw = newValue.rawValue }
    }

    public var actionType: AutomationActionType {
        get { AutomationActionType(rawValue: actionTypeRaw) ?? .text }
        set { actionTypeRaw = newValue.rawValue }
    }
}
