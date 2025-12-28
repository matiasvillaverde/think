import Abstractions
import Foundation
import Testing

@testable import AgentOrchestrator

@Suite("WorkspaceContextProvider Tests")
internal struct WorkspaceContextProviderTests {
    @Test("Loads workspace bootstrap files in order")
    internal func loadsWorkspaceFiles() throws {
        let fileManager: FileManager = FileManager.default
        let rootURL: URL = fileManager.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try fileManager.createDirectory(at: rootURL, withIntermediateDirectories: true)
        defer { try? fileManager.removeItem(at: rootURL) }

        let agentsURL: URL = rootURL.appendingPathComponent("AGENTS.md")
        let toolsURL: URL = rootURL.appendingPathComponent("TOOLS.md")
        try "Agents content".write(to: agentsURL, atomically: true, encoding: .utf8)
        try "Tools content".write(to: toolsURL, atomically: true, encoding: .utf8)

        let provider: WorkspaceContextProvider = WorkspaceContextProvider(rootURL: rootURL)
        let context: WorkspaceContext? = provider.loadContext()

        #expect(context?.sections.count == 2)
        #expect(context?.sections.first?.title == "AGENTS.md")
        #expect(context?.sections.first?.content == "Agents content")
        #expect(context?.sections.last?.title == "TOOLS.md")
        #expect(context?.sections.last?.content == "Tools content")
    }
}
