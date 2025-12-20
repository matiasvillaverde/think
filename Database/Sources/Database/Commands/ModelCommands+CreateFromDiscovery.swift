import Foundation
import SwiftData
import OSLog
import Abstractions

/// Sendable snapshot of DiscoveredModel data for use in non-MainActor contexts
private struct DiscoveredModelSnapshot: Sendable {
    let name: String
    let author: String
    let license: String?
    let licenseUrl: String?
    let modelCard: String?
    let tags: [String]
    let downloads: Int
    let likes: Int
    let lastModified: Date
    let files: [Abstractions.ModelFile]
}

extension ModelCommands {
    /// Command to create or update a model from a DiscoveredModel
    public struct CreateFromDiscovery: WriteCommand {
        // MARK: - Properties

        /// Logger for model creation operations
        private static let logger = Logger(
            subsystem: "Database",
            category: "ModelCommands.CreateFromDiscovery"
        )

        private let discoveredModelSnapshot: DiscoveredModelSnapshot
        private let sendableModel: SendableModel
        private let initialState: Model.State

        // MARK: - Initialization

        @preconcurrency
        @MainActor
        public init(
            discoveredModel: DiscoveredModel,
            sendableModel: SendableModel,
            initialState: Model.State = .downloadingActive
        ) {
            // Create a sendable snapshot of the DiscoveredModel data
            self.discoveredModelSnapshot = DiscoveredModelSnapshot(
                name: discoveredModel.name,
                author: discoveredModel.author,
                license: discoveredModel.license,
                licenseUrl: discoveredModel.licenseUrl,
                modelCard: discoveredModel.modelCard,
                tags: discoveredModel.tags,
                downloads: discoveredModel.downloads,
                likes: discoveredModel.likes,
                lastModified: discoveredModel.lastModified,
                files: discoveredModel.files
            )
            self.sendableModel = sendableModel
            self.initialState = initialState

            Self.logger.info("""
                CreateFromDiscovery command created - \
                Name: \(discoveredModel.name, privacy: .public), \
                Author: \(discoveredModel.author, privacy: .public), \
                Backend: \(String(describing: sendableModel.backend), privacy: .public)
                """
            )
        }

        // MARK: - Command Execution

        public func execute(
            in context: ModelContext,
            userId: PersistentIdentifier?,
            rag: Ragging?
        ) throws -> UUID {
            Self.logger.notice("Starting model creation from discovery")

            let startTime = CFAbsoluteTimeGetCurrent()

            do {
                // Validate user ID
                guard let userId = userId else {
                    Self.logger.error("User ID not provided")
                    throw DatabaseError.userNotFound
                }

                // Validate discovered model data
                try validateDiscoveredModelData()

                Self.logger.info("Creating model for user: \(userId.hashValue, privacy: .private)")

                let user = try context.getUser(id: userId)
                Self.logger.debug("User retrieved successfully")

                // Check if model already exists by ID or location
                let existingModel = user.models.first { model in
                    // Check by ID first
                    if model.id == sendableModel.id {
                        Self.logger.debug("Found existing model by ID: \(model.id)")
                        return true
                    }
                    // Check by location
                    if model.locationHuggingface == sendableModel.location {
                        Self.logger.debug("Found existing model by location: \(model.locationHuggingface ?? "nil")")
                        return true
                    }
                    return false
                }

                if let existingModel = existingModel {
                    Self.logger.info("Model already exists, updating: \(discoveredModelSnapshot.name, privacy: .public)")
                    updateModel(existingModel, from: sendableModel, context: context)
                    try context.save()

                    let executionTime = CFAbsoluteTimeGetCurrent() - startTime
                    Self.logger.notice("Model update completed in \(String(format: "%.3f", executionTime))s")

                    return existingModel.id
                }

                // Create new model
                Self.logger.info("Creating new model: \(discoveredModelSnapshot.name, privacy: .public)")

                // Calculate total size from files
                let totalSize = discoveredModelSnapshot.files.compactMap(\.size).reduce(0, +)

                // Extract architecture from sendable model metadata
                let architecture = sendableModel.metadata?.architecture ?? .unknown

                // Create new model directly using the initializer
                let model = try Model(
                    type: sendableModel.modelType,
                    backend: sendableModel.backend,
                    name: discoveredModelSnapshot.name,
                    displayName: discoveredModelSnapshot.name,
                    displayDescription: discoveredModelSnapshot.modelCard?.prefix(200).appending("...") ??
                        "Model from \(discoveredModelSnapshot.author)",
                    author: discoveredModelSnapshot.author,
                    license: discoveredModelSnapshot.license,
                    licenseUrl: discoveredModelSnapshot.licenseUrl,
                    tags: discoveredModelSnapshot.tags,
                    downloads: discoveredModelSnapshot.downloads,
                    likes: discoveredModelSnapshot.likes,
                    lastModified: discoveredModelSnapshot.lastModified,
                    skills: [], // Will be populated later
                    parameters: 1, // Default to 1 to avoid validation error, will be updated after download
                    ramNeeded: sendableModel.ramNeeded,
                    size: UInt64(totalSize), // Use actual total size from files
                    locationHuggingface: sendableModel.location,
                    version: 2, // Downloaded models should be version 2
                    architecture: architecture
                )
                model.id = sendableModel.id // Override the auto-generated ID
                model.state = initialState

                // Insert the model into the context
                context.insert(model)
                
                // Log the model state right after creation
                Self.logger.debug("""
                    Model after creation - ID: \(model.id), \
                    Name: \(model.name), \
                    Type: \(String(describing: model.type)), \
                    Backend: \(String(describing: model.backend))
                    """)

                // Ensure HuggingFace location is set correctly
                model.locationHuggingface = sendableModel.location

                // Add ModelFile entities from DiscoveredModel files
                for discoveredFile in discoveredModelSnapshot.files {
                    let modelFile = ModelFile(from: discoveredFile)
                    modelFile.model = model
                    // Don't append to model.files - SwiftData handles this through the relationship
                    context.insert(modelFile)
                }

                // Create ModelDetails if there's a model card
                if let modelCard = discoveredModelSnapshot.modelCard, !modelCard.isEmpty {
                    let details = ModelDetails(modelCard: modelCard)
                    details.model = model
                    // Don't set model.details - SwiftData handles this through the relationship
                    context.insert(details)
                }

                // Add model to user
                if user.models.isEmpty {
                    user.models = [model]
                } else {
                    user.models.append(model)
                }
                
                // Log model state before save
                Self.logger.debug("""
                    Model before save - ID: \(model.id), \
                    Name: \(model.name), \
                    Backend: \(String(describing: model.backend))
                    """)
                Self.logger.debug("User has \(user.models.count) models")

                Self.logger.debug("Saving context changes...")
                try context.save()

                let executionTime = CFAbsoluteTimeGetCurrent() - startTime
                Self.logger.notice("Model creation completed in \(String(format: "%.3f", executionTime))s")
                Self.logger.info("Created model: \(model.displayName, privacy: .public) (ID: \(model.id))")

                return model.id
            } catch {
                let executionTime = CFAbsoluteTimeGetCurrent() - startTime
                Self.logger.error("Model creation failed after \(String(format: "%.3f", executionTime))s: \(error.localizedDescription)")
                throw error
            }
        }

        // MARK: - Helper Methods

        private func updateModel(_ model: Model, from sendableModel: SendableModel, context: ModelContext) {
            Self.logger.debug("Updating model properties")

            // Update basic model properties
            model.type = sendableModel.modelType
            model.backend = sendableModel.backend
            model.ramNeeded = sendableModel.ramNeeded

            // Update metadata from discovered model snapshot
            model.author = discoveredModelSnapshot.author
            model.license = discoveredModelSnapshot.license
            model.licenseUrl = discoveredModelSnapshot.licenseUrl
            // Convert string tags to Tag entities
            model.tags = discoveredModelSnapshot.tags.map { Tag(name: $0) }
            model.downloads = discoveredModelSnapshot.downloads
            model.likes = discoveredModelSnapshot.likes
            model.lastModified = discoveredModelSnapshot.lastModified

            // Clear old ModelFile entities to ensure data consistency
            Self.logger.debug("Clearing old ModelFile entities")
            model.files.removeAll()

            // Add updated ModelFile entities from DiscoveredModel files
            for discoveredFile in discoveredModelSnapshot.files {
                let modelFile = ModelFile(from: discoveredFile)
                modelFile.model = model
                model.files.append(modelFile)
                context.insert(modelFile)
            }
            Self.logger.debug("Updated \(model.files.count) ModelFile entities")

            // Update or create ModelDetails if there's a model card
            if let modelCard = discoveredModelSnapshot.modelCard, !modelCard.isEmpty {
                if let existingDetails = model.details {
                    // Update existing details
                    existingDetails.modelCard = modelCard
                    Self.logger.debug("Updated existing ModelDetails")
                } else {
                    // Create new details
                    let details = ModelDetails(modelCard: modelCard)
                    details.model = model
                    model.details = details
                    context.insert(details)
                    Self.logger.debug("Created new ModelDetails")
                }
            } else if model.details != nil {
                // Remove details if no model card
                model.details = nil
                Self.logger.debug("Removed ModelDetails (no model card)")
            }

            // Keep download state if already downloading
            if case .downloadingActive = model.state {
                Self.logger.debug("Model is actively downloading, keeping state")
            } else if case .downloadingPaused = model.state {
                Self.logger.debug("Model download is paused, keeping state")
            } else {
                model.state = Model.State.downloadingActive
                model.downloadProgress = 0.0
            }

            Self.logger.debug("Model properties and relationships updated")
        }

        // MARK: - Validation

        /// Validates that the discovered model data is complete and valid for persistence
        private func validateDiscoveredModelData() throws {
            Self.logger.debug("Validating discovered model data")

            // Essential fields validation
            guard !discoveredModelSnapshot.name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
                Self.logger.error("Model name is empty or whitespace only")
                throw DatabaseError.invalidInput("Model name cannot be empty")
            }

            guard !discoveredModelSnapshot.author.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
                Self.logger.error("Model author is empty or whitespace only")
                throw DatabaseError.invalidInput("Model author cannot be empty")
            }

            // Files validation - critical for model functionality
            guard !discoveredModelSnapshot.files.isEmpty else {
                Self.logger.error("Model has no files - cannot create unusable model")
                throw DatabaseError.invalidInput("Model must have at least one file")
            }

            // Check for at least one model file (not just config files)
            let hasModelFiles = discoveredModelSnapshot.files.contains { file in
                // For CoreML, ZIP files ARE model files
                if sendableModel.backend == .coreml, file.fileExtension == "zip" {
                    return true
                }
                return file.isModelFile
            }

            guard hasModelFiles else {
                Self.logger.error("Model has no actual model files (only config/metadata files)")
                throw DatabaseError.invalidInput("Model must contain at least one model weight file")
            }

            // SendableModel validation
            guard !sendableModel.location.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
                Self.logger.error("SendableModel location is empty")
                throw DatabaseError.invalidInput("Model location cannot be empty")
            }

            // Optional but suspicious conditions - log warnings
            if discoveredModelSnapshot.modelCard?.isEmpty == true {
                Self.logger.warning("Model card is empty - model may lack proper documentation")
            }

            if discoveredModelSnapshot.tags.isEmpty {
                Self.logger.warning("Model has no tags - may affect discoverability and categorization")
            }

            if discoveredModelSnapshot.downloads == 0, discoveredModelSnapshot.likes == 0 {
                Self.logger.warning("Model has no downloads or likes - may be new or unpopular")
            }

            Self.logger.debug("Discovered model data validation passed")
        }
    }
}
