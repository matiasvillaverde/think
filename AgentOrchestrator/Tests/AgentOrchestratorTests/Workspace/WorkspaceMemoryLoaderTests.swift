import Abstractions
import Foundation
import Testing

@testable import AgentOrchestrator

@Suite("WorkspaceMemoryLoader Tests")
@MainActor
internal struct WorkspaceMemoryLoaderTests {
    @Test("Loads MEMORY.md and daily logs from workspace")
    internal func loadsMemoryFiles() throws {
        let tempDir: URL = try makeTempDirectory()
        defer { try? FileManager.default.removeItem(at: tempDir) }

        try writeMemoryFixtures(to: tempDir)
        let fixedDate: Date? = fixedDate()
        #expect(fixedDate != nil)
        guard let fixedDate else {
            return
        }

        let context: MemoryContext? = WorkspaceMemoryLoader(rootURL: tempDir) { fixedDate }.loadContext()

        #expect(context?.longTermMemories.count == 1)
        #expect(context?.longTermMemories.first?.content == "Long-term memory")
        #expect(context?.recentDailyLogs.count == 2)
        #expect(context?.recentDailyLogs.map(\.content).contains("Today log") == true)
        #expect(context?.recentDailyLogs.map(\.content).contains("Yesterday log") == true)
    }

    @Test("Returns nil when no memory files exist")
    internal func returnsNilWhenEmpty() throws {
        let tempDir: URL = try makeTempDirectory()
        defer { try? FileManager.default.removeItem(at: tempDir) }

        let loader: WorkspaceMemoryLoader = WorkspaceMemoryLoader(rootURL: tempDir)
        #expect(loader.loadContext() == nil)
    }

    private func makeTempDirectory() throws -> URL {
        let base: URL = FileManager.default.temporaryDirectory
        let dir: URL = base.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir
    }

    private func write(_ content: String, to url: URL) throws {
        let directory: URL = url.deletingLastPathComponent()
        if !FileManager.default.fileExists(atPath: directory.path) {
            try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        }
        guard let data: Data = content.data(using: .utf8) else {
            throw CocoaError(.fileWriteUnknown)
        }
        try data.write(to: url, options: [.atomic])
    }

    private func writeMemoryFixtures(to rootURL: URL) throws {
        try write("Long-term memory", to: rootURL.appendingPathComponent("MEMORY.md"))
        try write("Today log", to: rootURL.appendingPathComponent("memory/2026-02-02.md"))
        try write("Yesterday log", to: rootURL.appendingPathComponent("memory/daily/2026-02-01.md"))
    }

    private func fixedDate() -> Date? {
        let dateComponents: DateComponents = DateComponents(
            calendar: Calendar(identifier: .iso8601),
            year: 2_026,
            month: 2,
            day: 2
        )
        return dateComponents.date
    }
}
