import Abstractions
import Foundation
import OSLog

public final actor FilePluginTrustStore: PluginTrustStoring {
    private static let logger: Logger = Logger(
        subsystem: AgentOrchestratorConfiguration.shared.logging.subsystem,
        category: "PluginTrustStore"
    )

    private let fileURL: URL
    private let fileManager: FileManager
    private let encoder: JSONEncoder
    private let decoder: JSONDecoder

    public init(fileURL: URL) {
        self.fileURL = fileURL
        self.fileManager = FileManager()
        self.encoder = JSONEncoder()
        self.decoder = JSONDecoder()
        self.encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
    }

    public func load() async throws -> PluginTrustSnapshot {
        try Task.checkCancellation()
        await Task.yield()
        guard fileManager.fileExists(atPath: fileURL.path) else {
            return PluginTrustSnapshot()
        }

        do {
            let data: Data = try Data(contentsOf: fileURL)
            return try decoder.decode(PluginTrustSnapshot.self, from: data)
        } catch {
            Self.logger.warning("Failed to load plugin trust store, returning empty snapshot")
            return PluginTrustSnapshot()
        }
    }

    public func save(_ snapshot: PluginTrustSnapshot) async throws {
        await Task.yield()
        try ensureDirectoryExists()
        let data: Data = try encoder.encode(snapshot)
        try data.write(to: fileURL, options: [.atomic])
    }

    private func ensureDirectoryExists() throws {
        let directoryURL: URL = fileURL.deletingLastPathComponent()
        if !fileManager.fileExists(atPath: directoryURL.path) {
            try fileManager.createDirectory(
                at: directoryURL,
                withIntermediateDirectories: true
            )
        }
    }
}
