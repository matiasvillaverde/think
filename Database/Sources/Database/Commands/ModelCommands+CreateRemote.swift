import Abstractions
import Foundation
import OSLog
import SwiftData

// MARK: - Remote Model Creation
extension ModelCommands {
    /// Command to create or update a remote model entry.
    public struct CreateRemoteModel: WriteCommand {
        private static let logger = Logger(
            subsystem: "Database",
            category: "ModelCommands.CreateRemoteModel"
        )

        private let name: String
        private let displayName: String
        private let displayDescription: String
        private let location: String
        private let type: SendableModel.ModelType
        private let architecture: Architecture

        public init(
            name: String,
            displayName: String,
            displayDescription: String,
            location: String,
            type: SendableModel.ModelType = .language,
            architecture: Architecture = .unknown
        ) {
            self.name = name
            self.displayName = displayName
            self.displayDescription = displayDescription
            self.location = location
            self.type = type
            self.architecture = architecture
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
                model.locationKind == .remote && model.locationHuggingface == location
            }) {
                Self.logger.info("Remote model already exists, updating: \(existing.id)")
                existing.name = name
                existing.displayName = displayName
                existing.displayDescription = displayDescription
                existing.type = type
                existing.backend = .remote
                existing.architecture = architecture
                existing.locationKind = .remote
                existing.locationHuggingface = location
                existing.state = .downloaded
                existing.downloadProgress = 1.0
                try context.save()
                return existing.id
            }

            let model = try Model(
                type: type,
                backend: .remote,
                name: name,
                displayName: displayName,
                displayDescription: displayDescription,
                tags: [],
                downloads: 0,
                likes: 0,
                lastModified: Date(),
                skills: [],
                parameters: 0,
                ramNeeded: 0,
                size: 0,
                locationHuggingface: location,
                locationKind: .remote,
                locationLocal: nil,
                locationBookmark: nil,
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
            Self.logger.info("Created remote model: \(model.id)")
            return model.id
        }
    }
}
