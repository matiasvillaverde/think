import Foundation
import SwiftData
import OSLog

/// Commands for managing application settings.
public enum SettingsCommands {}

public enum SettingUpdate<Value> {
    case noChange
    case set(Value)
}

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
        private let talkModeEnabled: SettingUpdate<Bool>
        private let wakeWordEnabled: SettingUpdate<Bool>
        private let wakePhrase: SettingUpdate<String>

        public init(
            talkModeEnabled: SettingUpdate<Bool> = .noChange,
            wakeWordEnabled: SettingUpdate<Bool> = .noChange,
            wakePhrase: SettingUpdate<String> = .noChange
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

            switch talkModeEnabled {
            case .set(let value):
                settings.talkModeEnabled = value
            case .noChange:
                break
            }
            switch wakeWordEnabled {
            case .set(let value):
                settings.wakeWordEnabled = value
            case .noChange:
                break
            }
            switch wakePhrase {
            case .set(let value):
                settings.wakePhrase = value
            case .noChange:
                break
            }
            settings.updatedAt = Date()

            try context.save()
            Logger.database.info("Updated voice settings")
            return settings.id
        }
    }

    /// Updates node mode settings.
    public struct UpdateNode: WriteCommand {
        private let nodeModeEnabled: SettingUpdate<Bool>
        private let nodeModePort: SettingUpdate<Int>
        private let nodeModeAuthToken: SettingUpdate<String?>

        public init(
            nodeModeEnabled: SettingUpdate<Bool> = .noChange,
            nodeModePort: SettingUpdate<Int> = .noChange,
            nodeModeAuthToken: SettingUpdate<String?> = .noChange
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

            switch nodeModeEnabled {
            case .set(let value):
                settings.nodeModeEnabled = value
            case .noChange:
                break
            }
            switch nodeModePort {
            case .set(let value):
                settings.nodeModePort = value
            case .noChange:
                break
            }
            switch nodeModeAuthToken {
            case .set(let value):
                settings.nodeModeAuthToken = value
            case .noChange:
                break
            }
            settings.updatedAt = Date()

            try context.save()
            Logger.database.info("Updated node mode settings")
            return settings.id
        }
    }
}
