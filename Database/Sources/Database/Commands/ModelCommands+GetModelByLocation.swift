import Foundation
import SwiftData
import OSLog
import Abstractions

// swiftlint:disable nesting

extension ModelCommands {
    /// Command to retrieve a model by its HuggingFace location
    public struct GetModelByLocation: ReadCommand {
        public typealias Result = Model?

        private let location: String
        private static let logger = Logger(
            subsystem: "Database",
            category: "\(ModelCommands.self).GetModelByLocation"
        )

        public init(location: String) {
            self.location = location
        }

        public func execute(
            in context: ModelContext,
            userId: PersistentIdentifier?,
            rag: Ragging?
        ) throws -> Model? {
            Self.logger.info("Fetching model with location: \(self.location, privacy: .public)")

            guard let userId = userId else {
                Self.logger.error("User ID not provided")
                throw DatabaseError.userNotFound
            }

            let user = try context.getUser(id: userId)
            Self.logger.debug("User retrieved, has \(user.models.count) models")

            // Find model by HuggingFace location
            let model = user.models.first { model in
                if model.locationHuggingface == self.location {
                    return true
                }
                return false
            }

            if let model = model {
                Self.logger.info("Found model: \(model.displayName, privacy: .public)")
                return model
            } else {
                Self.logger.debug("No model found for location: \(self.location)")
                return nil
            }
        }
    }
}
