import Foundation
import SwiftData
import OSLog
import Abstractions

// MARK: - Model Fetch Commands
extension ModelCommands {
    public struct FetchAll: ReadCommand {
        public typealias Result = [SendableModel]
        public var requiresUser: Bool { true }
        public var requiresRag: Bool { false }

        public init() {}

        public func execute(
            in context: ModelContext,
            userId: PersistentIdentifier?,
            rag: Ragging?
        ) throws -> [SendableModel] {
            guard let userId = userId else {
                throw DatabaseError.userNotFound
            }

            // Get the user
            let userDescriptor = FetchDescriptor<User>(
                predicate: #Predicate { $0.persistentModelID == userId }
            )

            guard let user = try context.fetch(userDescriptor).first else {
                throw DatabaseError.userNotFound
            }

            // Convert to sendable models
            return user.models.map { model in
                model.toSendable()
            }
        }
    }

    public struct GetPromptModel: ReadCommand {
        // MARK: - Properties

        /// Logger for prompt model retrieval operations
        private static let logger = Logger(subsystem: "Database", category: "ModelCommands")

        public typealias Result = Model

        // MARK: - Initialization

        public init() {}

        // MARK: - Command Execution

        public func execute(
            in context: ModelContext,
            userId: PersistentIdentifier?,
            rag: Ragging?
        ) throws -> Model {
            do {
                let descriptor = FetchDescriptor<Model>(
                    predicate: #Predicate<Model> { model in
                        model.name == "Prompt Categorizer"
                    }
                )

                guard let model = try context.fetch(descriptor).first else {
                    Self.logger.error("Prompt Categorizer model not found")
                    throw DatabaseError.modelNotFound
                }

                Self.logger.info("Prompt model retrieved: \(model.displayName, privacy: .public)")
                return model
            } catch {
                Self.logger.error("Prompt model retrieval failed: \(error.localizedDescription)")
                throw error
            }
        }
    }

    public struct GetModelForType: ReadCommand {
        // MARK: - Properties

        /// Logger for model type retrieval operations
        private static let logger = Logger(subsystem: "Database", category: "ModelCommands")

        public typealias Result = Model
        private let type: SendableModel.ModelType

        // MARK: - Initialization

        public init(type: SendableModel.ModelType) {
            self.type = type
        }

        // MARK: - Command Execution

        public func execute(
            in context: ModelContext,
            userId: PersistentIdentifier?,
            rag: Ragging?
        ) throws -> Model {
            do {
                guard let userId = userId else {
                    throw DatabaseError.userNotFound
                }

                let user = try context.getUser(id: userId)

                // Filter user models by type and downloaded status, then sort by RAM
                let matchingModels = user.models
                    .filter { $0.type == type && $0.state?.isDownloaded == true }
                    .sorted { $0.ramNeeded < $1.ramNeeded }

                guard let model = matchingModels.first else {
                    Self.logger.error("No downloaded model found for type: \(String(describing: type), privacy: .public)")
                    throw DatabaseError.modelNotFound
                }

                Self.logger.info("Model retrieved for type \(String(describing: type), privacy: .public): \(model.displayName, privacy: .public)")
                return model
            } catch {
                Self.logger.error("Model retrieval failed: \(error.localizedDescription)")
                throw error
            }
        }
    }

    public struct GetModel: ReadCommand {
        // MARK: - Properties

        /// Logger for model name retrieval operations
        private static let logger = Logger(subsystem: "Database", category: "ModelCommands")

        public typealias Result = Model
        private let name: String

        // MARK: - Initialization

        public init(name: String) {
            self.name = name
        }

        // MARK: - Command Execution

        public func execute(
            in context: ModelContext,
            userId: PersistentIdentifier?,
            rag: Ragging?
        ) throws -> Model {
            do {
                let descriptor = FetchDescriptor<Model>(
                    predicate: #Predicate<Model> { model in
                        model.name == name
                    }
                )

                guard let model = try context.fetch(descriptor).first else {
                    Self.logger.error("Model not found with name: \(name, privacy: .public)")
                    throw DatabaseError.modelNotFound
                }

                Self.logger.info("Model retrieved: \(model.displayName, privacy: .public)")
                return model
            } catch {
                Self.logger.error("Model retrieval failed: \(error.localizedDescription)")
                throw error
            }
        }
    }

    public struct GetModelFromId: ReadCommand {
        // MARK: - Properties

        /// Logger for model ID retrieval operations
        private static let logger = Logger(subsystem: "Database", category: "ModelCommands")

        public typealias Result = Model
        private let id: UUID

        // MARK: - Initialization

        public init(id: UUID) {
            self.id = id
        }

        // MARK: - Command Execution

        public func execute(
            in context: ModelContext,
            userId: PersistentIdentifier?,
            rag: Ragging?
        ) throws -> Model {
            do {
                let descriptor = FetchDescriptor<Model>(
                    predicate: #Predicate<Model> { model in
                        model.id == id
                    }
                )

                guard let model = try context.fetch(descriptor).first else {
                    Self.logger.error("Model not found with ID: \(id)")
                    throw DatabaseError.modelNotFound
                }

                return model
            } catch {
                Self.logger.error("Model retrieval failed: \(error.localizedDescription)")
                throw error
            }
        }
    }
}
