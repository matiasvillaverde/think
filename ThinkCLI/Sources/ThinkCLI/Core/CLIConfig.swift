import Foundation

struct CLIConfig: Codable, Equatable, Sendable {
    var workspacePath: String?
    var defaultModelId: UUID?
    var preferredSkills: [String]
    var lastOnboardedAt: Date?

    init(
        workspacePath: String? = nil,
        defaultModelId: UUID? = nil,
        preferredSkills: [String] = [],
        lastOnboardedAt: Date? = nil
    ) {
        self.workspacePath = workspacePath
        self.defaultModelId = defaultModelId
        self.preferredSkills = preferredSkills
        self.lastOnboardedAt = lastOnboardedAt
    }
}
