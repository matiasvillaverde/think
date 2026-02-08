import Abstractions
import Foundation
import OSLog
import SwiftData

/// Commands for managing application settings.
public enum SettingsCommands {}

public enum SettingUpdate<Value: Sendable>: Sendable {
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

// MARK: - OpenClaw Gateway Instances

extension SettingsCommands {
    /// Returns all configured OpenClaw instances along with the active instance id.
    public struct FetchOpenClawInstances: ReadCommand {
        public typealias Result = [OpenClawInstanceRecord]

        public init() {}

        public func execute(
            in context: ModelContext,
            userId: PersistentIdentifier?,
            rag: Ragging?
        ) throws -> [OpenClawInstanceRecord] {
            _ = rag
            guard let userId else {
                throw DatabaseError.userNotFound
            }
            let user = try context.getUser(id: userId)
            let settings: AppSettings = user.settings ?? AppSettings()
            if user.settings == nil {
                user.settings = settings
                context.insert(settings)
                try context.save()
            }

            let activeId: UUID? = settings.activeOpenClawInstanceId
            return settings.openClawInstances
                .sorted { $0.updatedAt > $1.updatedAt }
                .map { instance in
                    OpenClawInstanceRecord(
                        id: instance.id,
                        name: instance.name,
                        urlString: instance.urlString,
                        hasAuthToken: !(instance.authToken ?? "").isEmpty,
                        isActive: instance.id == activeId,
                        createdAt: instance.createdAt,
                        updatedAt: instance.updatedAt
                    )
                }
        }
    }

    /// Returns the full configuration for a specific OpenClaw instance.
    public struct GetOpenClawInstanceConfiguration: ReadCommand {
        public typealias Result = OpenClawInstanceConfiguration

        private let id: UUID

        public init(id: UUID) {
            self.id = id
        }

        public func execute(
            in context: ModelContext,
            userId: PersistentIdentifier?,
            rag: Ragging?
        ) throws -> OpenClawInstanceConfiguration {
            _ = rag
            guard let userId else {
                throw DatabaseError.userNotFound
            }
            let user = try context.getUser(id: userId)
            let settings: AppSettings = user.settings ?? AppSettings()
            if user.settings == nil {
                user.settings = settings
                context.insert(settings)
                try context.save()
            }

            guard let instance = settings.openClawInstances.first(where: { $0.id == id }) else {
                throw DatabaseError.invalidInput("OpenClaw instance not found")
            }

            return OpenClawInstanceConfiguration(
                id: instance.id,
                name: instance.name,
                urlString: instance.urlString,
                authToken: instance.authToken
            )
        }
    }

    /// Creates or updates a configured OpenClaw instance.
    public struct UpsertOpenClawInstance: WriteCommand {
        private let id: UUID?
        private let name: String
        private let urlString: String
        private let authToken: String?

        public init(
            id: UUID? = nil,
            name: String,
            urlString: String,
            authToken: String?
        ) {
            self.id = id
            self.name = name
            self.urlString = urlString
            self.authToken = authToken
        }

        public func execute(
            in context: ModelContext,
            userId: PersistentIdentifier?,
            rag: Ragging?
        ) throws -> UUID {
            _ = rag
            guard let userId else {
                throw DatabaseError.userNotFound
            }
            let user = try context.getUser(id: userId)
            let settings: AppSettings = user.settings ?? AppSettings()
            if user.settings == nil {
                user.settings = settings
                context.insert(settings)
            }

            let trimmedName: String = name.trimmingCharacters(in: .whitespacesAndNewlines)
            let trimmedURL: String = urlString.trimmingCharacters(in: .whitespacesAndNewlines)
            let trimmedToken: String? = authToken?.trimmingCharacters(in: .whitespacesAndNewlines)
            let finalToken: String? = (trimmedToken?.isEmpty ?? true) ? nil : trimmedToken

            if let id,
               let existing = settings.openClawInstances.first(where: { $0.id == id }) {
                existing.name = trimmedName
                existing.urlString = trimmedURL
                existing.authToken = finalToken
                existing.updatedAt = Date()
                settings.updatedAt = Date()
                try context.save()
                Logger.database.info("Updated OpenClawInstance \(id)")
                return existing.id
            }

            let newInstance = OpenClawInstance(
                name: trimmedName,
                urlString: trimmedURL,
                authToken: finalToken
            )
            settings.openClawInstances.append(newInstance)
            context.insert(newInstance)
            settings.updatedAt = Date()

            // Auto-select the first configured instance.
            if settings.activeOpenClawInstanceId == nil {
                settings.activeOpenClawInstanceId = newInstance.id
            }

            try context.save()
            Logger.database.info("Created OpenClawInstance \(newInstance.id)")
            return newInstance.id
        }
    }

    /// Deletes an OpenClaw instance by ID.
    public struct DeleteOpenClawInstance: WriteCommand {
        private let id: UUID

        public init(id: UUID) {
            self.id = id
        }

        public func execute(
            in context: ModelContext,
            userId: PersistentIdentifier?,
            rag: Ragging?
        ) throws -> UUID {
            _ = rag
            guard let userId else {
                throw DatabaseError.userNotFound
            }
            let user = try context.getUser(id: userId)
            let settings: AppSettings = user.settings ?? AppSettings()
            if user.settings == nil {
                user.settings = settings
                context.insert(settings)
            }

            if let index = settings.openClawInstances.firstIndex(where: { $0.id == id }) {
                let instance = settings.openClawInstances.remove(at: index)
                context.delete(instance)
                if settings.activeOpenClawInstanceId == id {
                    settings.activeOpenClawInstanceId = settings.openClawInstances.first?.id
                }
                settings.updatedAt = Date()
                try context.save()
                Logger.database.info("Deleted OpenClawInstance \(id)")
            }

            return id
        }
    }

    /// Sets the active OpenClaw instance.
    public struct SetActiveOpenClawInstance: WriteCommand {
        private let id: UUID?

        public init(id: UUID?) {
            self.id = id
        }

        public func execute(
            in context: ModelContext,
            userId: PersistentIdentifier?,
            rag: Ragging?
        ) throws -> UUID {
            _ = rag
            guard let userId else {
                throw DatabaseError.userNotFound
            }
            let user = try context.getUser(id: userId)
            let settings: AppSettings = user.settings ?? AppSettings()
            if user.settings == nil {
                user.settings = settings
                context.insert(settings)
            }

            settings.activeOpenClawInstanceId = id
            settings.updatedAt = Date()
            try context.save()
            Logger.database.info("Set active OpenClaw instance to \(id?.uuidString ?? "nil")")
            return settings.id
        }
    }
}
