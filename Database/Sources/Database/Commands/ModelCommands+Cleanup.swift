import Foundation
import SwiftData
import OSLog
import Abstractions
import SwiftUI

// MARK: - Model Cleanup Commands
extension ModelCommands {
    public struct DeleteModelLocation: WriteCommand {
        private let model: UUID

        public init(model: UUID) {
            self.model = model
            Logger.database.info("ModelCommands.DeleteModelLocation initialized with model: \(model)")
        }

        public func execute(
            in context: ModelContext,
            userId: PersistentIdentifier?,
            rag: Ragging?
        ) throws -> UUID {
            Logger.database.info("ModelCommands.DeleteModelLocation.execute started for model: \(model)")

            let descriptor = FetchDescriptor<Model>(
                predicate: #Predicate<Model> { $0.id == model }
            )

            Logger.database.info("Fetching model with id: \(model)")
            let models = try context.fetch(descriptor)

            guard let model = models.first else {
                Logger.database.error("ModelCommands.DeleteModelLocation.execute failed: model not found with id: \(model)")
                throw DatabaseError.modelNotFound
            }

            Logger.database.info("Found model: \(model.id), current state: \(String(describing: model.state))")
            Logger.database.info("Setting model state to notDownloaded")
            model.state = .notDownloaded

            Logger.database.info("Saving context")
            try context.save()

            Logger.database.info("ModelCommands.DeleteModelLocation.execute completed successfully")
            return model.id
        }
    }

    public struct CleanupCancelledDownload: WriteCommand {
        private let modelId: UUID

        public init(modelId: UUID) {
            self.modelId = modelId
            Logger.database.info("ModelCommands.CleanupCancelledDownload initialized with modelId: \(modelId)")
        }

        public func execute(
            in context: ModelContext,
            userId: PersistentIdentifier?,
            rag: Ragging?
        ) throws -> UUID {
            Logger.database.info("ModelCommands.CleanupCancelledDownload.execute started for model: \(modelId)")

            let descriptor = FetchDescriptor<Model>(
                predicate: #Predicate<Model> { $0.id == modelId }
            )

            Logger.database.info("Fetching model with id: \(modelId)")
            let models = try context.fetch(descriptor)

            guard let model = models.first else {
                Logger.database.error("ModelCommands.CleanupCancelledDownload.execute failed: model not found with id: \(modelId)")
                throw DatabaseError.modelNotFound
            }

            Logger.database.info("Found model: \(model.id), current state: \(String(describing: model.state))")

            // Only cleanup if model is in a downloading state
            switch model.state {
            case .downloadingActive, .downloadingPaused:
                Logger.database.info("Model is in downloading state, resetting to notDownloaded")
                model.state = .notDownloaded

                Logger.database.info("Saving context")
                try context.save()

                Logger.database.info("ModelCommands.CleanupCancelledDownload.execute completed successfully")
            default:
                Logger.database.info("Model is not in downloading state, no cleanup needed. Current state: \(String(describing: model.state))")
            }

            return model.id
        }
    }

    public struct ResetAllRuntimeStates: WriteCommand {
        // MARK: - Properties

        /// Logger for runtime state reset operations
        private static let logger = Logger(subsystem: "Database", category: "ModelCommands")

        // MARK: - Initialization

        public init() {}

        // MARK: - Command Execution

        public func execute(
            in context: ModelContext,
            userId: PersistentIdentifier?,
            rag: Ragging?
        ) throws -> UUID {
            do {
                guard let userId = userId else {
                    throw DatabaseError.userNotFound
                }

                let user = try context.getUser(id: userId)

                var resetCount = 0
                for model in user.models {
                    let oldState = model.runtimeState
                    model.resetRuntimeState()
                    if oldState != .notLoaded {
                        resetCount += 1
                    }
                }

                try context.save()

                if resetCount > 0 {
                    Self.logger.info("Runtime state reset completed - Reset \(resetCount) models")
                }

                return user.id
            } catch {
                Self.logger.error("Runtime state reset failed: \(error.localizedDescription)")
                throw error
            }
        }
    }
}
