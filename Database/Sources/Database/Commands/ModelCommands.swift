import Foundation
import SwiftData
import OSLog
import Abstractions
import SwiftUI

// swiftlint:disable line_length nesting

// MARK: - Model Commands
public enum ModelCommands {
    public struct AddModels: WriteCommand {
        // MARK: - Properties

        /// Logger for model addition operations
        private static let logger = Logger(subsystem: "Database", category: "ModelCommands")

        public let models: [ModelDTO]

        // MARK: - Initialization

        @available(*, deprecated, message: "Use init(modelDTOs:) for clarity")
        public init(models: [ModelDTO]) {
            self.models = models
        }
        
        public init(modelDTOs: [ModelDTO]) {
            self.models = modelDTOs
        }

        // MARK: - Command Execution

        public func execute(
            in context: ModelContext,
            userId: PersistentIdentifier?,
            rag: Ragging?
        ) throws -> UUID {
            do {
                // Validate user ID
                guard let userId = userId else {
                    throw DatabaseError.userNotFound
                }

                let user = try context.getUser(id: userId)

                // Filter models by available memory
                let availableMemory = ProcessInfo.processInfo.physicalMemory
                let eligibleModels = models.filter { $0.ramNeeded <= availableMemory }
                let filteredCount = models.count - eligibleModels.count

                if filteredCount > 0 {
                    Self.logger.warning("Filtered out \(filteredCount) models due to insufficient memory")
                }

                var updatedCount = 0
                var addedCount = 0

                // Update existing models and add new ones
                for dto in eligibleModels {
                    if let index = user.models.firstIndex(where: { $0.name == dto.name }) {
                        // Update existing model
                        try update(model: user.models[index], from: dto)
                        updatedCount += 1
                    } else {
                        // Add new model
                        let newModel = try dto.createModel()

                        if user.models.isEmpty {
                            user.models = [newModel]
                        } else {
                            user.models.append(newModel)
                        }
                        addedCount += 1
                    }
                }

                try context.save()

                let resultId = user.models.first?.id ?? user.id
                Self.logger.info("Model addition/update completed - Added: \(addedCount), Updated: \(updatedCount), Total: \(user.models.count)")

                return resultId
            } catch {
                Self.logger.error("Model addition/update failed: \(error.localizedDescription)")
                throw error
            }
        }

        // MARK: - Helper Methods

        func update(model: Model, from dto: ModelDTO) throws {
            model.type = dto.type
            model.name = dto.name
            model.displayName = dto.displayName
            model.displayDescription = dto.displayDescription
            // Merge both dto.tags and dto.skills into unified tags
            let allTagNames = Set(dto.tags + dto.skills)
            model.tags = allTagNames.map { Tag(name: $0) }
            model.parameters = dto.parameters
            model.ramNeeded = dto.ramNeeded
            model.size = dto.size
            model.state = .notDownloaded // Default to not Downloaded
            model.locationHuggingface = dto.locationHuggingface
        }
    }
}
