import Foundation
import SwiftData
import OSLog
import Abstractions

// MARK: - Local Model Creation
extension ModelCommands {
    /// Command to create or update a locally-referenced model entry.
    public struct CreateLocalModel: WriteCommand {
        private static let logger = Logger(
            subsystem: "Database",
            category: "ModelCommands.CreateLocalModel"
        )

        private let name: String
        private let backend: SendableModel.Backend
        private let type: SendableModel.ModelType
        private let parameters: UInt64
        private let ramNeeded: UInt64
        private let size: UInt64
        private let architecture: Architecture
        private let locationLocal: String
        private let locationBookmark: Data?

        public init(
            name: String,
            backend: SendableModel.Backend,
            type: SendableModel.ModelType,
            parameters: UInt64,
            ramNeeded: UInt64,
            size: UInt64,
            architecture: Architecture = .unknown,
            locationLocal: String,
            locationBookmark: Data?
        ) {
            self.name = name
            self.backend = backend
            self.type = type
            self.parameters = parameters
            self.ramNeeded = ramNeeded
            self.size = size
            self.architecture = architecture
            self.locationLocal = locationLocal
            self.locationBookmark = locationBookmark
        }

        public func execute(
            in context: ModelContext,
            userId: PersistentIdentifier?,
            rag: Ragging?
        ) throws -> UUID {
            guard let userId else {
                throw DatabaseError.userNotFound
            }

            let user = try context.getUser(id: userId)

            if let existing = user.models.first(where: { model in
                model.locationKind == .localFile && model.locationLocal == locationLocal
            }) {
                Self.logger.info("Local model already exists, updating: \(existing.id)")
                existing.name = name
                existing.displayName = name
                existing.backend = backend
                existing.type = type
                existing.parameters = parameters
                existing.ramNeeded = ramNeeded
                existing.size = size
                existing.architecture = architecture
                existing.locationKind = .localFile
                existing.locationLocal = locationLocal
                existing.locationBookmark = locationBookmark
                existing.state = .downloaded
                existing.downloadProgress = 1.0
                try context.save()
                return existing.id
            }

            let model = try Model(
                type: type,
                backend: backend,
                name: name,
                displayName: name,
                displayDescription: "Local model",
                tags: [],
                downloads: 0,
                likes: 0,
                lastModified: Date(),
                skills: [],
                parameters: parameters,
                ramNeeded: ramNeeded,
                size: size,
                locationHuggingface: "",
                locationKind: .localFile,
                locationLocal: locationLocal,
                locationBookmark: locationBookmark,
                version: 2,
                architecture: architecture
            )
            model.state = .downloaded
            model.downloadProgress = 1.0

            context.insert(model)

            if user.models.isEmpty {
                user.models = [model]
            } else {
                user.models.append(model)
            }

            try context.save()
            Self.logger.info("Created local model: \(model.id)")
            return model.id
        }
    }
}
