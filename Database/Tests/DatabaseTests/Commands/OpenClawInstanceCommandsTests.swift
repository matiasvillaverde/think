import Abstractions
import AbstractionsTestUtilities
@testable import Database
import Testing

@Suite("OpenClaw Instance Commands Tests")
struct OpenClawInstanceCommandsTests {
    private func createTestDatabase() throws -> Database {
        let config = DatabaseConfiguration(
            isStoredInMemoryOnly: true,
            allowsSave: true,
            ragFactory: MockRagFactory(mockRag: MockRagging())
        )
        return try Database.new(configuration: config)
    }

    @Test("UpsertOpenClawInstance creates and auto-selects first instance")
    @MainActor
    func upsertCreatesAndSelects() async throws {
        let database = try createTestDatabase()
        _ = try await database.execute(AppCommands.Initialize())

        let id = try await database.write(
            SettingsCommands.UpsertOpenClawInstance(
                name: "Home",
                urlString: "wss://example.com/gateway",
                authToken: "token"
            )
        )

        let instances = try await database.read(SettingsCommands.FetchOpenClawInstances())
        #expect(instances.count == 1)
        #expect(instances.first?.id == id)
        #expect(instances.first?.isActive == true)
        #expect(instances.first?.hasAuthToken == true)
    }

    @Test("SetActiveOpenClawInstance switches active instance")
    @MainActor
    func setActiveSwitches() async throws {
        let database = try createTestDatabase()
        _ = try await database.execute(AppCommands.Initialize())

        let first = try await database.write(
            SettingsCommands.UpsertOpenClawInstance(
                name: "A",
                urlString: "wss://a.example/gateway",
                authToken: nil
            )
        )
        let second = try await database.write(
            SettingsCommands.UpsertOpenClawInstance(
                name: "B",
                urlString: "wss://b.example/gateway",
                authToken: nil
            )
        )

        _ = try await database.write(SettingsCommands.SetActiveOpenClawInstance(id: second))
        let instances = try await database.read(SettingsCommands.FetchOpenClawInstances())
        let active = instances.first(where: { $0.isActive })

        #expect(active?.id == second)
        #expect(instances.contains(where: { $0.id == first }))
    }

    @Test("DeleteOpenClawInstance removes and reselects active")
    @MainActor
    func deleteRemovesAndReselects() async throws {
        let database = try createTestDatabase()
        _ = try await database.execute(AppCommands.Initialize())

        let first = try await database.write(
            SettingsCommands.UpsertOpenClawInstance(
                name: "A",
                urlString: "wss://a.example/gateway",
                authToken: nil
            )
        )
        let second = try await database.write(
            SettingsCommands.UpsertOpenClawInstance(
                name: "B",
                urlString: "wss://b.example/gateway",
                authToken: nil
            )
        )
        _ = try await database.write(SettingsCommands.SetActiveOpenClawInstance(id: second))

        _ = try await database.write(SettingsCommands.DeleteOpenClawInstance(id: second))
        let instances = try await database.read(SettingsCommands.FetchOpenClawInstances())

        #expect(instances.count == 1)
        #expect(instances.first?.id == first)
        #expect(instances.first?.isActive == true)
    }

    @Test("GetOpenClawInstanceConfiguration returns token and url")
    @MainActor
    func getConfigurationReturnsFields() async throws {
        let database = try createTestDatabase()
        _ = try await database.execute(AppCommands.Initialize())

        let id = try await database.write(
            SettingsCommands.UpsertOpenClawInstance(
                name: "Home",
                urlString: "https://example.com/gateway",
                authToken: "abc"
            )
        )

        let config = try await database.read(
            SettingsCommands.GetOpenClawInstanceConfiguration(id: id)
        )

        #expect(config.id == id)
        #expect(config.urlString.contains("example.com"))
        #expect(config.authToken == "abc")
    }
}

