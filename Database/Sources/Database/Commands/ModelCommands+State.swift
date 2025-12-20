import Foundation
import SwiftData
import OSLog
import Abstractions
import SwiftUI

// MARK: - Model State Commands
extension ModelCommands {
    public struct UpdateModelDownloadProgress: WriteCommand {
        // MARK: - Properties

        /// Logger for download progress operations
        private static let logger = Logger(subsystem: "Database", category: "ModelCommands")

        private let id: UUID
        private let progress: Double

        // MARK: - Initialization

        public init(id: UUID, progress: Double) {
            self.id = id
            self.progress = progress
        }

        public func execute(
            in context: ModelContext,
            userId: PersistentIdentifier?,
            rag: Ragging?
        ) throws -> UUID {
            do {
                let model = try GetModelFromId(id: id).execute(in: context, userId: userId, rag: rag)

                // Validate model is in correct state for downloading
                switch model.state {
                case .notDownloaded, .downloadingActive, .downloadingPaused, .none:
                    break // These states are valid for updates
                case .downloaded:
                    // If already downloaded, ignore the update - this handles race conditions
                    Self.logger.warning("Download progress update skipped (already downloaded)")
                    return model.id
                }

                // Validate progress value
                let validProgress = max(0, min(1, progress))
                if validProgress != progress {
                    Self.logger.warning("Progress value clamped from \(String(format: "%.3f", progress)) to \(String(format: "%.3f", validProgress))")
                }

                // Update model state and progress
                model.downloadProgress = validProgress
                
                if validProgress == 1 {
                    Self.logger.info("Download completed - Setting model to downloaded state")
                    model.state = .downloaded
                    // NOTE: We do NOT set downloadedLocation here - it should be set by a separate command
                    // after the download is fully completed and verified
                } else {
                    withAnimation(.easeIn) {
                        model.state = .downloadingActive
                    }
                }

                try context.save()
                Self.logger.notice("Download progress update - Model: \(id), Progress: \(String(format: "%.1f", progress * 100))%")
                return model.id
            } catch {
                Self.logger.error("Download progress update failed: \(error.localizedDescription)")
                throw error
            }
        }
    }

    public struct PauseDownload: WriteCommand {
        // MARK: - Properties

        /// Logger for pause download operations
        private static let logger = Logger(subsystem: "Database", category: "ModelCommands")

        private let id: UUID

        // MARK: - Initialization

        public init(id: UUID) {
            self.id = id
        }

        public func execute(
            in context: ModelContext,
            userId: PersistentIdentifier?,
            rag: Ragging?
        ) throws -> UUID {
            do {
                let model = try GetModelFromId(id: id).execute(in: context, userId: userId, rag: rag)

                // Validate model is in correct state for pausing
                guard model.state == .downloadingActive else {
                    Self.logger.warning("Invalid state for pause - Current state: \(String(describing: model.state))")
                    throw Model.ModelError.invalidStateTransition
                }

                // Update model state to paused (progress is already stored separately)
                withAnimation(.easeOut) {
                    model.state = .downloadingPaused
                }

                try context.save()
                Self.logger.info("Download paused - Model: \(id), Progress: \(String(format: "%.1f", (model.downloadProgress ?? 0) * 100))%")
                return model.id
            } catch {
                Self.logger.error("Download pause failed: \(error.localizedDescription)")
                throw error
            }
        }
    }

    public struct ResumeDownload: WriteCommand {
        // MARK: - Properties

        /// Logger for resume download operations
        private static let logger = Logger(subsystem: "Database", category: "ModelCommands")

        private let id: UUID

        // MARK: - Initialization

        public init(id: UUID) {
            self.id = id
        }

        public func execute(
            in context: ModelContext,
            userId: PersistentIdentifier?,
            rag: Ragging?
        ) throws -> UUID {
            do {
                let model = try GetModelFromId(id: id).execute(in: context, userId: userId, rag: rag)

                // Validate model is in correct state for resuming
                guard model.state == .downloadingPaused else {
                    Self.logger.warning("Invalid state for resume - Current state: \(String(describing: model.state))")
                    throw Model.ModelError.invalidStateTransition
                }

                // Update model state to active (progress is already stored separately)
                withAnimation(.easeIn) {
                    model.state = .downloadingActive
                }

                try context.save()
                Self.logger.info("Download resumed - Model: \(id), Progress: \(String(format: "%.1f", (model.downloadProgress ?? 0) * 100))%")
                return model.id
            } catch {
                Self.logger.error("Download resume failed: \(error.localizedDescription)")
                throw error
            }
        }
    }

    public struct GetModelState: ReadCommand {
        // MARK: - Properties

        /// Logger for model state retrieval operations
        private static let logger = Logger(subsystem: "Database", category: "ModelCommands")

        public typealias Result = Model.State
        private let id: UUID

        // MARK: - Initialization

        public init(id: UUID) {
            self.id = id
        }

        public func execute(
            in context: ModelContext,
            userId: PersistentIdentifier?,
            rag: Ragging?
        ) throws -> Model.State {
            do {
                let model = try GetModelFromId(id: id).execute(in: context, userId: userId, rag: rag)
                return model.state ?? .notDownloaded
            } catch {
                Self.logger.error("Model state retrieval failed: \(error.localizedDescription)")
                throw error
            }
        }
    }

    public struct MarkModelAsDownloaded: WriteCommand {
        // MARK: - Properties

        /// Logger for mark as downloaded operations
        private static let logger = Logger(subsystem: "Database", category: "ModelCommands")

        private let id: UUID

        // MARK: - Initialization

        public init(id: UUID) {
            self.id = id
        }

        public func execute(
            in context: ModelContext,
            userId: PersistentIdentifier?,
            rag: Ragging?
        ) throws -> UUID {
            do {
                let model = try GetModelFromId(id: id).execute(in: context, userId: userId, rag: rag)

                // Update model state
                model.state = .downloaded
                try context.save()

                Self.logger.info("Model marked as downloaded: \(id)")
                return model.id
            } catch {
                Self.logger.error("Mark as downloaded failed: \(error.localizedDescription)")
                throw error
            }
        }
    }

    public struct TransitionRuntimeState: WriteCommand {
        // MARK: - Properties

        /// Logger for runtime state transition operations
        private static let logger = Logger(subsystem: "Database", category: "ModelCommands")

        private let id: UUID
        private let transition: Model.RuntimeTransition

        // MARK: - Initialization

        public init(id: UUID, transition: Model.RuntimeTransition) {
            self.id = id
            self.transition = transition
        }

        // MARK: - Command Execution

        public func execute(
            in context: ModelContext,
            userId: PersistentIdentifier?,
            rag: Ragging?
        ) throws -> UUID {
            do {
                let model = try GetModelFromId(id: id).execute(in: context, userId: userId, rag: rag)

                let oldState = model.runtimeState

                // Apply the transition using the model's state machine
                if let newState = model.transitionRuntimeState(transition) {
                    try context.save()
                    Self.logger.info("Runtime state transition completed - Model: \(id), \(String(describing: oldState)) -> \(String(describing: newState))")
                    return model.id
                } else {
                    Self.logger.warning("Invalid runtime state transition - Model: \(id), Transition: \(String(describing: transition))")
                    // Return the model ID even for invalid transitions to avoid throwing
                    return model.id
                }
            } catch {
                Self.logger.error("Runtime state transition failed: \(error.localizedDescription)")
                throw error
            }
        }
    }
}
