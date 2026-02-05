import Abstractions
import AbstractionsTestUtilities
import Database
import Foundation
import Testing
@testable import Tools

@Suite("ToolManager Memory Tool Tests")
internal struct ToolManagerMemoryToolTests {
    @Test("Configure memory tool registers and writes")
    @MainActor
    func configureMemoryToolRegistersAndWrites() async throws {
        let database: Database = try await Self.makeDatabase()
        let toolManager: ToolManager = ToolManager(database: database)

        await toolManager.configureTool(identifiers: [.memory])
        let definitions: [ToolDefinition] = await toolManager.getAllToolDefinitions()
        #expect(definitions.contains { $0.name == "memory" })

        let request: ToolRequest = ToolRequest(
            name: "memory",
            arguments: "{\"type\":\"longTerm\",\"content\":\"Prefers espresso\",\"keywords\":[\"coffee\"]}",
            context: nil
        )
        let responses: [ToolResponse] = await toolManager.executeTools(toolRequests: [request])
        #expect(responses.first?.error == nil)

        let memories: [Memory] = try await database.read(
            MemoryCommands.GetByType(type: .longTerm)
        )
        #expect(memories.count == 1)
        #expect(memories.first?.content.contains("Prefers espresso") == true)
    }

    private static func makeDatabase() async throws -> Database {
        let config: DatabaseConfiguration = DatabaseConfiguration(
            isStoredInMemoryOnly: true,
            allowsSave: true,
            ragFactory: MockRagFactory(mockRag: MockRagging())
        )
        let database: Database = try Database.new(configuration: config)
        _ = try await database.execute(AppCommands.Initialize())
        return database
    }
}
