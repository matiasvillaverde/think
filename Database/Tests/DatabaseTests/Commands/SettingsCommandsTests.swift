import Abstractions
import AbstractionsTestUtilities
import Foundation
import Testing
@testable import Database

@Suite("Settings Commands Tests")
struct SettingsCommandsTests {
    @Test("GetOrCreate creates default settings")
    @MainActor
    func getOrCreateCreatesDefaults() async throws {
        let database = try await Self.makeDatabase()

        let settings = try await database.read(SettingsCommands.GetOrCreate())

        #expect(settings.talkModeEnabled == false)
        #expect(settings.wakeWordEnabled == true)
        #expect(settings.wakePhrase == "hey think")
        #expect(settings.nodeModeEnabled == false)
        #expect(settings.nodeModePort == 9876)
    }

    @Test("UpdateVoice persists voice settings")
    @MainActor
    func updateVoicePersists() async throws {
        let database = try await Self.makeDatabase()

        _ = try await database.write(SettingsCommands.UpdateVoice(
            talkModeEnabled: true,
            wakeWordEnabled: false,
            wakePhrase: "hey tests"
        ))

        let settings = try await database.read(SettingsCommands.GetOrCreate())
        #expect(settings.talkModeEnabled == true)
        #expect(settings.wakeWordEnabled == false)
        #expect(settings.wakePhrase == "hey tests")
    }

    @Test("UpdateNode persists node settings")
    @MainActor
    func updateNodePersists() async throws {
        let database = try await Self.makeDatabase()

        _ = try await database.write(SettingsCommands.UpdateNode(
            nodeModeEnabled: true,
            nodeModePort: 7777,
            nodeModeAuthToken: "token"
        ))

        let settings = try await database.read(SettingsCommands.GetOrCreate())
        #expect(settings.nodeModeEnabled == true)
        #expect(settings.nodeModePort == 7777)
        #expect(settings.nodeModeAuthToken == "token")
    }

    private static func makeDatabase() async throws -> Database {
        let config = DatabaseConfiguration(
            isStoredInMemoryOnly: true,
            allowsSave: true,
            ragFactory: MockRagFactory(mockRag: MockRagging())
        )
        let database = try Database.new(configuration: config)
        _ = try await database.execute(AppCommands.Initialize())
        return database
    }
}
