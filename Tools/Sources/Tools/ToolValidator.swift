import Abstractions
import Database
import Foundation
import OSLog

/// Validates tool requirements and availability
public actor ToolValidator: ToolValidating {
    private let database: DatabaseProtocol
    private let healthKitAvailability: HealthKitAvailabilityChecking
    private let logger: Logger = Logger(subsystem: "Tools", category: "ToolValidator")

    /// Creates a tool validator
    /// - Parameter database: Database used to resolve model requirements
    public init(database: DatabaseProtocol) {
        self.database = database
        self.healthKitAvailability = DefaultHealthKitAvailabilityChecker()
    }

    internal init(
        database: DatabaseProtocol,
        healthKitAvailability: HealthKitAvailabilityChecking
    ) {
        self.database = database
        self.healthKitAvailability = healthKitAvailability
    }

    public func validateToolRequirements(
        _ tool: ToolIdentifier,
        chatId: UUID
    ) async throws -> ToolValidationResult {
        switch tool {
        case .imageGeneration:
            return try await validateImageGeneration(chatId: chatId)

        case .healthKit:
            return validateHealthKit()

        case .browser, .python, .functions, .weather, .duckduckgo, .braveSearch, .memory,
            .subAgent, .workspace, .cron, .canvas, .nodes:
            return .available
        }
    }

    private func validateImageGeneration(chatId: UUID) async throws -> ToolValidationResult {
        let sendableModel: SendableModel = try await database.read(
            ChatCommands.GetImageModel(chatId: chatId)
        )
        let downloadInfo: ModelCommands.ModelDownloadInfo = try await database.read(
            ModelCommands.GetModelDownloadInfo(id: sendableModel.id)
        )

        if downloadInfo.state.isDownloaded != true {
            logger.info("Image model not downloaded: \(downloadInfo.id)")
            return .requiresDownload(modelId: downloadInfo.id, size: downloadInfo.size)
        }

        let requiredMemory: UInt64 = downloadInfo.ramNeeded
        let availableMemory: UInt64 = ProcessInfo.processInfo.physicalMemory
        if requiredMemory > availableMemory {
            logger.info("Insufficient memory for image model: \(sendableModel.id)")
            return .insufficientMemory(required: requiredMemory, available: availableMemory)
        }

        return .available
    }

    private func validateHealthKit() -> ToolValidationResult {
        healthKitAvailability.isAvailable() ? .available : .notSupported
    }
}

// MARK: - HealthKit Availability

internal protocol HealthKitAvailabilityChecking: Sendable {
    func isAvailable() -> Bool
}

internal struct DefaultHealthKitAvailabilityChecker: HealthKitAvailabilityChecking {
    func isAvailable() -> Bool {
        HealthKitManager().isHealthKitAvailable()
    }
}
