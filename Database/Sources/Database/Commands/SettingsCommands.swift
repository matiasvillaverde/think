import Foundation
import SwiftData
import OSLog

/// Commands for managing application settings.
public enum SettingsCommands {}

extension SettingsCommands {
    /// Fetches settings for the current user, creating defaults if missing.
    public struct GetOrCreate: ReadCommand {
        public typealias Result = AppSettings

        public init() {}

        public func execute(
            in context: ModelContext,
            userId: PersistentIdentifier?,
            rag: Ragging?
        ) throws -> AppSettings {
            guard let userId else {
                throw DatabaseError.userNotFound
            }
            let user = try context.getUser(id: userId)

            if let existing = user.settings {
                return existing
            }

            let settings = AppSettings()
            user.settings = settings
            context.insert(settings)
            try context.save()
            Logger.database.info("Created default AppSettings for user")
            return settings
        }
    }

    /// Updates voice-related settings.
    public struct UpdateVoice: WriteCommand {
        private let talkModeEnabled: Bool?
        private let wakeWordEnabled: Bool?
        private let wakePhrase: String?

        public init(
            talkModeEnabled: Bool? = nil,
            wakeWordEnabled: Bool? = nil,
            wakePhrase: String? = nil
        ) {
            self.talkModeEnabled = talkModeEnabled
            self.wakeWordEnabled = wakeWordEnabled
            self.wakePhrase = wakePhrase
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
            let settings = user.settings ?? AppSettings()

            if user.settings == nil {
                user.settings = settings
                context.insert(settings)
            }

            if let talkModeEnabled {
                settings.talkModeEnabled = talkModeEnabled
            }
            if let wakeWordEnabled {
                settings.wakeWordEnabled = wakeWordEnabled
            }
            if let wakePhrase {
                settings.wakePhrase = wakePhrase
            }
            settings.updatedAt = Date()

            try context.save()
            Logger.database.info("Updated voice settings")
            return settings.id
        }
    }

    /// Updates node mode settings.
    public struct UpdateNode: WriteCommand {
        private let nodeModeEnabled: Bool?
        private let nodeModePort: Int?
        private let nodeModeAuthToken: String?

        public init(
            nodeModeEnabled: Bool? = nil,
            nodeModePort: Int? = nil,
            nodeModeAuthToken: String? = nil
        ) {
            self.nodeModeEnabled = nodeModeEnabled
            self.nodeModePort = nodeModePort
            self.nodeModeAuthToken = nodeModeAuthToken
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
            let settings = user.settings ?? AppSettings()

            if user.settings == nil {
                user.settings = settings
                context.insert(settings)
            }

            if let nodeModeEnabled {
                settings.nodeModeEnabled = nodeModeEnabled
            }
            if let nodeModePort {
                settings.nodeModePort = nodeModePort
            }
            if let nodeModeAuthToken {
                settings.nodeModeAuthToken = nodeModeAuthToken
            }
            settings.updatedAt = Date()

            try context.save()
            Logger.database.info("Updated node mode settings")
            return settings.id
        }
    }
}
