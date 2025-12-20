import Foundation
import SwiftData
import Abstractions
import DataAssets
import OSLog

// swiftlint:disable line_length

/// Screen that the app should display after initialization
public enum AppScreen: CustomStringConvertible, Sendable {
    case welcome       // User needs to download models or no chats exist
    case chat          // User has v2 models and chats, ready to use app

    public var description: String {
        switch self {
        case .welcome: return "welcome"
        case .chat: return "chat"
        }
    }
}

/// Installation type for app initialization
private enum InstallationType: CustomStringConvertible {
    case newInstall        // No user exists
    case migration         // User exists, only v0/v1 models
    case existingUser      // User exists, has v2 models

    var description: String {
        switch self {
        case .newInstall: return "newInstall"
        case .migration: return "migration"
        case .existingUser: return "existingUser"
        }
    }
}

/// Result of app initialization containing user ID and target screen
public struct AppInitializationResult: Sendable {
    public let userId: UUID
    public let targetScreen: AppScreen

    public init(userId: UUID, targetScreen: AppScreen) {
        self.userId = userId
        self.targetScreen = targetScreen
    }
}

/// Command to initialize application state based on installation type.
/// Handles three distinct scenarios:
/// 1. New Install: Creates user, adds only v2 image model, shows welcome screen
/// 2. Migration: Migrates v0→v1 models, adds v2 image model, shows welcome screen
/// 3. Existing User: Creates chats only with v2 models, shows appropriate screen
public struct AppInitializeCommand: AnonymousCommand {
    public typealias Result = AppInitializationResult

    // MARK: - Properties

    /// Logger for initialization operations
    private static let logger = Logger(
        subsystem: "Database",
        category: "AppInitialize"
    )

    // MARK: - Initialization

    public init() {
        Self.logger.info("AppInitialize command created")
    }

    // MARK: - Helper Methods

    /// Reset all model runtime states to .notLoaded on app startup
    private func resetAllModelRuntimeStates(in context: ModelContext) throws {
        let descriptor = FetchDescriptor<Model>()
        let models = try context.fetch(descriptor)

        for model in models {
            model.resetRuntimeState()
        }

        try context.save()
        Self.logger.debug("Reset runtime states for \(models.count) models")
    }

    // MARK: - Command Execution

    public func execute(in context: ModelContext) throws -> AppInitializationResult {
            Self.logger.notice("Starting application initialization")
            let startTime = CFAbsoluteTimeGetCurrent()

            do {
                // Reset all model runtime states to .notLoaded when app starts
                try resetAllModelRuntimeStates(in: context)
                Self.logger.info("Reset all model runtime states on app startup")

                // Detect installation type
                let installationType = try detectInstallationType(in: context)
                Self.logger.info("Detected installation type: \(installationType)")

                let result: AppInitializationResult

                switch installationType {
                case .newInstall:
                    result = try handleNewInstall(in: context)
                case .migration:
                    result = try handleMigration(in: context)
                case .existingUser:
                    result = try handleExistingUser(in: context)
                }

                let executionTime = CFAbsoluteTimeGetCurrent() - startTime
                Self.logger.notice("Application initialization completed successfully in \(String(format: "%.3f", executionTime))s for user: \(result.userId) -> \(result.targetScreen)")

                return result
            } catch {
                let executionTime = CFAbsoluteTimeGetCurrent() - startTime
                Self.logger.error("Application initialization failed after \(String(format: "%.3f", executionTime))s: \(error.localizedDescription)")
                throw error
            }
        }

        // MARK: - Installation Type Detection

        private func detectInstallationType(in context: ModelContext) throws -> InstallationType {
            Self.logger.info("Detecting installation type...")

            // Check if user exists
            let userDescriptor = FetchDescriptor<User>()
            let existingUsers = try context.fetch(userDescriptor)

            if existingUsers.isEmpty {
                Self.logger.info("No users found - NEW INSTALL")
                return .newInstall
            }

            let user = existingUsers[0]
            Self.logger.info("Found existing user: \(user.id)")

            // Check if user has any v2 models
            let hasV2Models = user.models.contains { $0.version == 2 }

            if hasV2Models {
                Self.logger.info("User has v2 models - EXISTING USER")
                return .existingUser
            } else {
                Self.logger.info("User has no v2 models - MIGRATION")
                return .migration
            }
        }

        // MARK: - New Install Handler

        private func handleNewInstall(in context: ModelContext) throws -> AppInitializationResult {
            Self.logger.notice("Handling new installation")

            // Create new user
            let user = User()
            context.insert(user)
            try context.save()
            Self.logger.info("Created new user: \(user.id)")

            // Add default personalities
            try addDefaultPersonalities(in: context)

            // Create only v2 image model (device-appropriate)
            try addV2ImageModel(for: user, in: context)

            // NO chat creation - user must choose language model via welcome screen
            Self.logger.info("Skipping chat creation - user will select language model via welcome screen")

            Self.logger.notice("New install completed successfully")
            return AppInitializationResult(userId: user.id, targetScreen: .welcome)
        }

        // MARK: - Migration Handler

        private func handleMigration(in context: ModelContext) throws -> AppInitializationResult {
            Self.logger.notice("Handling migration from legacy version")

            // Get existing user
            let userDescriptor = FetchDescriptor<User>()
            let user = try context.fetch(userDescriptor)[0]
            Self.logger.info("Using existing user: \(user.id)")
            
            // Debug: Check existing models
            Self.logger.info("Found \(user.models.count) existing models")
            for model in user.models {
                Self.logger.debug("Model: \(model.name), version: \(model.version ?? 0), locationHuggingface: '\(model.locationHuggingface ?? "")'")
            }

            // Migrate v0 models to v1
            try migrateV0ModelsToV1(for: user, in: context)

            // Sync personalities
            try syncPersonalities(in: context)

            // Add v2 image model if missing
            let hasV2ImageModel = user.models.contains { $0.type == .diffusion && $0.version == 2 }
            if !hasV2ImageModel {
                try addV2ImageModel(for: user, in: context)
            } else {
                Self.logger.info("V2 image model already exists")
            }

            // NO chat creation - user must download v2 language model
            Self.logger.info("Skipping chat creation - user must download v2 language model")

            Self.logger.notice("Migration completed successfully")
            return AppInitializationResult(userId: user.id, targetScreen: .welcome)
        }

        // MARK: - Existing User Handler

        private func handleExistingUser(in context: ModelContext) throws -> AppInitializationResult {
            Self.logger.notice("Handling existing user with v2 models")

            // Get existing user
            let userDescriptor = FetchDescriptor<User>()
            let user = try context.fetch(userDescriptor)[0]
            Self.logger.info("Using existing user: \(user.id)")
            
            // Debug: Check existing models
            Self.logger.info("Found \(user.models.count) existing models")
            for model in user.models {
                Self.logger.debug("Model: \(model.name), version: \(model.version ?? 0), locationHuggingface: '\(model.locationHuggingface ?? "")'")
            }

            // Sync personalities (fast path)
            try syncPersonalities(in: context)

            // Model states are now ephemeral and reset automatically
            // No need to explicitly reset them on startup

            // Handle chat creation with v2 models only
            let chatWasCreated = try handleChatCreationForExistingUser(for: user, in: context)

            // Determine target screen based on whether chats were created
            let targetScreen: AppScreen = chatWasCreated ? .chat : .welcome

            Self.logger.notice("Existing user handling completed successfully -> \(targetScreen)")
            return AppInitializationResult(userId: user.id, targetScreen: targetScreen)
        }

        // MARK: - Model Management

        private func migrateV0ModelsToV1(for user: User, in context: ModelContext) throws {
            Self.logger.info("Migrating v0 models to v1")

            var migrationCount = 0
            for model in user.models where model.version == 0 {
                Self.logger.debug("Migrating model \(model.name) from v0 to v1")
                model.version = 1
                migrationCount += 1
            }

            if migrationCount > 0 {
                Self.logger.info("Migrated \(migrationCount) models from v0 to v1")
                try context.save()
            } else {
                Self.logger.info("No models needed migration from v0 to v1")
            }
        }

        private func addV2ImageModel(for user: User, in context: ModelContext) throws {
            Self.logger.info("Adding device-appropriate v2 image model")

            // Get device capabilities for optimal model selection
            let capabilities = DeviceModelSelector.getCurrentDeviceCapabilities()
            Self.logger.info("Device capabilities: \(capabilities.memoryCategory) memory, \(capabilities.totalMemory / 1024 / 1024 / 1024)GB total")

            // Create optimal v2 image model
            let imageModel = try DeviceModelSelector.getOptimalImageModel(for: capabilities)
            imageModel.state = .notDownloaded

            context.insert(imageModel)
            user.models.append(imageModel)
            try context.save()

            Self.logger.info("Added v2 image model: \(imageModel.name) (RAM: \(imageModel.ramNeeded))")
        }

        // MARK: - Personality Management

        private func addDefaultPersonalities(in context: ModelContext) throws {
            Self.logger.info("Adding default personalities for new install")

            let factoryPersonalities = PersonalityFactory.createSystemPersonalities()
            for personality in factoryPersonalities {
                // SAFE: Use validated factory insertion
                try PersonalityFactory.insertSystemPersonalitySafely(personality, in: context)
            }
            try context.save()

            Self.logger.info("Added \(factoryPersonalities.count) default personalities")
        }

        private func syncPersonalities(in context: ModelContext) throws {
            Self.logger.info("Syncing personalities for existing user")

            // Fast check: Count existing system personalities
            let systemCountDescriptor = FetchDescriptor<Personality>(
                predicate: #Predicate { !$0.isCustom }
            )
            let existingSystemCount = try context.fetchCount(systemCountDescriptor)

            // Get expected count from factory
            let factoryPersonalities = PersonalityFactory.createSystemPersonalities()
            let expectedCount = factoryPersonalities.count

            // Fast path: If counts match, assume everything is up to date
            if existingSystemCount == expectedCount {
                Self.logger.info("Personality counts match (\(existingSystemCount)) - skipping detailed sync")
                return
            }

            // If no system personalities exist, bulk insert all
            if existingSystemCount == 0 {
                Self.logger.notice("No system personalities found - performing bulk insert")
                for personality in factoryPersonalities {
                    // SAFE: Use validated factory insertion
                    try PersonalityFactory.insertSystemPersonalitySafely(personality, in: context)
                }
                try context.save()
                Self.logger.info("Bulk personality insert completed - added \(factoryPersonalities.count) personalities")
                return
            }

            // Detailed sync if counts don't match
            Self.logger.warning("Personality count mismatch - performing detailed sync")
            try performDetailedPersonalitySync(in: context)
        }

        private func performDetailedPersonalitySync(in context: ModelContext) throws {
            let factoryPersonalities = PersonalityFactory.createSystemPersonalities()

            // Fetch existing system personalities
            let systemPersonalitiesDescriptor = FetchDescriptor<Personality>(
                predicate: #Predicate { !$0.isCustom }
            )
            let existingSystemPersonalities = try context.fetch(systemPersonalitiesDescriptor)

            // SAFE: Create lookup with duplicate detection and cleanup
            let (existingLookup, duplicatesFound) = try createSafePersonalityLookup(
                from: existingSystemPersonalities,
                in: context
            )

            var hasChanges = duplicatesFound > 0
            var addedCount = 0

            // Add missing personalities using safe method
            for factoryPersonality in factoryPersonalities where existingLookup[factoryPersonality.systemInstruction] == nil {
                // Use safe insertion to prevent race conditions
                do {
                    try PersonalityFactory.insertSystemPersonalitySafely(factoryPersonality, in: context)
                    hasChanges = true
                    addedCount += 1
                    Self.logger.debug("Added missing personality: \(String(describing: factoryPersonality.systemInstruction))")
                } catch PersonalityError.duplicateSystemPersonality(let instruction, _) {
                    Self.logger.warning("Personality \(String(describing: instruction)) was created concurrently, skipping")
                }
            }

            if hasChanges {
                try context.save()
                Self.logger.info("Detailed personality sync completed - added \(addedCount) personalities, cleaned \(duplicatesFound) duplicates")
            } else {
                Self.logger.info("Detailed personality sync completed - no changes needed")
            }
        }
        
        /// Creates a safe personality lookup dictionary with duplicate detection and cleanup
        /// - Parameters:
        ///   - personalities: Array of existing personalities
        ///   - context: ModelContext for cleanup operations
        /// - Returns: Tuple of (lookup dictionary, number of duplicates cleaned)
        /// - Throws: Database errors during cleanup
        private func createSafePersonalityLookup(
            from personalities: [Personality],
            in context: ModelContext
        ) throws -> ([SystemInstruction: Personality], Int) {
            var lookup: [SystemInstruction: Personality] = [:]
            var duplicatesFound: [SystemInstruction] = []
            var duplicatePersonalities: [Personality] = []
            
            // Build lookup and identify duplicates
            for personality in personalities {
                if lookup[personality.systemInstruction] != nil {
                    // Found duplicate
                    duplicatesFound.append(personality.systemInstruction)
                    duplicatePersonalities.append(personality)
                    Self.logger.warning("Duplicate personality detected: \(String(describing: personality.systemInstruction))")
                } else {
                    lookup[personality.systemInstruction] = personality
                }
            }
            
            // Clean up duplicates immediately
            if !duplicatePersonalities.isEmpty {
                Self.logger.notice("Cleaning up \(duplicatePersonalities.count) duplicate personalities")
                for duplicate in duplicatePersonalities {
                    context.delete(duplicate)
                    Self.logger.debug("Deleted duplicate: \(String(describing: duplicate.systemInstruction)) (ID: \(duplicate.id))")
                }
            }
            
            return (lookup, duplicatesFound.count)
        }

        // MARK: - Chat Management (V2 Models Only)

        private func handleChatCreationForExistingUser(for user: User, in context: ModelContext) throws -> Bool {
            Self.logger.info("Handling chat creation for existing user")

            // Check if user has v2 language-capable model (required for chat creation)
            let hasV2LanguageModel = user.models.contains {
                ($0.type == .language || $0.type == .deepLanguage || $0.type == .flexibleThinker) && $0.version == 2
            }

            Self.logger.debug("V2 models status - Language: \(hasV2LanguageModel)")

            guard hasV2LanguageModel else {
                Self.logger.info("Skipping chat creation - missing v2 models (Language: \(hasV2LanguageModel))")
                return false
            }

            // Check if user has existing chats
            let hasExistingChats = !user.chats.isEmpty

            if hasExistingChats {
                Self.logger.info("User has existing chats - creating launch chat with v2 models")
                try createLaunchChatWithV2Models(for: user, in: context)
            } else {
                Self.logger.info("User has no chats - creating initial chat with v2 models")
                try createInitialChatWithV2Models(for: user, in: context)
            }

            return true
        }

        private func createInitialChatWithV2Models(for user: User, in context: ModelContext) throws {
            Self.logger.info("Creating initial chat with v2 models")

            // Find any v2 language model
            let v2LanguageModel = user.models.first { model in
                (model.type == .language || model.type == .deepLanguage || model.type == .flexibleThinker) && model.version == 2
            }

            // Find any v2 image model
            let v2ImageModel = user.models.first { model in
                model.type == .diffusion && model.version == 2
            }

            guard let languageModel = v2LanguageModel,
                  let imageModel = v2ImageModel else {
                Self.logger.error("Cannot create initial chat - missing required v2 models")
                throw DatabaseError.cannotCreateFirstChat
            }

            Self.logger.info("Selected models - Language: \(languageModel.name), Image: \(imageModel.name)")

            // Get default personality
            let defaultPersonality = try getDefaultPersonality(in: context)

            // Create chat with v2 models only
            let chat = Chat(
                languageModelConfig: .default,
                languageModel: languageModel,
                imageModelConfig: .default,
                imageModel: imageModel,
                user: user,
                personality: defaultPersonality
            )

            context.insert(chat)
            try context.save()

            Self.logger.notice("Initial chat created successfully with v2 models")
        }

        private func createLaunchChatWithV2Models(for user: User, in context: ModelContext) throws {
            Self.logger.info("Checking if launch chat is needed")

            // Look for a suitable last chat with v2 models to reuse configuration
            let lastV2Chat = user.chats.reversed().first { chat in
                chat.languageModel.version == 2 && chat.imageModel.version == 2
            }

            if let lastChat = lastV2Chat {
                // Check if last chat is essentially empty (0 or 1 messages)
                let messageCount = lastChat.messages.count
                Self.logger.info("Last chat has \(messageCount) messages")
                
                if messageCount <= 1 {
                    Self.logger.info("Skipping launch chat creation - last chat has \(messageCount) messages")
                    return
                }
                
                Self.logger.info("Creating launch chat - last chat has \(messageCount) messages")
                Self.logger.info("Reusing v2 models from last chat: \(lastChat.languageModel.name)")

                let defaultPersonality = try getDefaultPersonality(in: context)

                let launchChat = Chat(
                    languageModelConfig: .default,
                    languageModel: lastChat.languageModel,
                    imageModelConfig: .default,
                    imageModel: lastChat.imageModel,
                    user: user,
                    personality: defaultPersonality
                )

                context.insert(launchChat)
                try context.save()

                Self.logger.notice("Launch chat created successfully reusing v2 models")
            } else {
                Self.logger.info("No previous v2 chat found - creating initial chat with v2 models")
                try createInitialChatWithV2Models(for: user, in: context)
            }
        }

        // MARK: - Helper Methods

        private func getDefaultPersonality(in context: ModelContext) throws -> Personality {
            let descriptor = FetchDescriptor<Personality>(
                predicate: #Predicate { $0.isDefault == true }
            )

            guard let personality = try context.fetch(descriptor).first else {
                Self.logger.error("Default personality not found")
                throw DatabaseError.personalityNotFound
            }

            return personality
        }
}

public enum AppCommands {
    public typealias Initialize = AppInitializeCommand
}
