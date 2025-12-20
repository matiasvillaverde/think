import Foundation
import SwiftData
import OSLog
import Abstractions

// MARK: - Model Utility Commands
extension ModelCommands {
    public struct GetModelRamNeeded: ReadCommand {
        public typealias Result = UInt64

        private let id: UUID

        public init(id: UUID) {
            self.id = id
        }

        public func execute(
            in context: ModelContext,
            userId: PersistentIdentifier?,
            rag: Ragging?
        ) throws -> UInt64 {
            let descriptor = FetchDescriptor<Model>(
                predicate: #Predicate<Model> { $0.id == id }
            )

            let models = try context.fetch(descriptor)

            guard let model = models.first else {
                throw DatabaseError.modelNotFound
            }

            return model.ramNeeded
        }
    }

    public struct GetModelType: ReadCommand {
        public typealias Result = SendableModel.ModelType

        private let id: UUID

        public init(id: UUID) {
            self.id = id
        }

        public func execute(
            in context: ModelContext,
            userId: PersistentIdentifier?,
            rag: Ragging?
        ) throws -> SendableModel.ModelType {
            let descriptor = FetchDescriptor<Model>(
                predicate: #Predicate<Model> { $0.id == id }
            )

            let models = try context.fetch(descriptor)

            guard let model = models.first else {
                throw DatabaseError.modelNotFound
            }

            return model.type
        }
    }

    public struct GetSendableModel: ReadCommand {
        public typealias Result = SendableModel

        private let id: UUID

        public init(id: UUID) {
            self.id = id
        }

        public func execute(
            in context: ModelContext,
            userId: PersistentIdentifier?,
            rag: Ragging?
        ) throws -> SendableModel {
            let descriptor = FetchDescriptor<Model>(
                predicate: #Predicate<Model> { $0.id == id }
            )

            let models = try context.fetch(descriptor)

            guard let model = models.first else {
                throw DatabaseError.modelNotFound
            }

            return model.toSendable()
        }
    }

    public struct GetModelName: ReadCommand {
        public typealias Result = String

        private let id: UUID

        public init(id: UUID) {
            self.id = id
        }

        public func execute(
            in context: ModelContext,
            userId: PersistentIdentifier?,
            rag: Ragging?
        ) throws -> String {
            let descriptor = FetchDescriptor<Model>(
                predicate: #Predicate<Model> { $0.id == id }
            )

            let models = try context.fetch(descriptor)

            guard let model = models.first else {
                throw DatabaseError.modelNotFound
            }

            return model.name
        }
    }

    public struct UserHasModels: ReadCommand {
        public typealias Result = Bool

        public init() {}

        public func execute(
            in context: ModelContext,
            userId: PersistentIdentifier?,
            rag: Ragging?
        ) throws -> Bool {
            guard let userId else {
                throw DatabaseError.userNotFound
            }

            let user = context.model(for: userId) as? User
            guard let user else {
                throw DatabaseError.userNotFound
            }

            return !user.models.isEmpty
        }
    }
}
