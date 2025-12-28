import Abstractions
import Foundation
import OSLog

/// Loads bootstrap context from workspace files.
internal struct WorkspaceContextProvider {
    private static let logger: Logger = Logger(
        subsystem: AgentOrchestratorConfiguration.shared.logging.subsystem,
        category: "WorkspaceContextProvider"
    )

    private let rootURL: URL
    private let fileManager: FileManager

    internal init(rootURL: URL, fileManager: FileManager = .default) {
        self.rootURL = rootURL
        self.fileManager = fileManager
    }

    internal func loadContext() -> WorkspaceContext? {
        let sections: [WorkspaceContextSection] = WorkspaceBootstrapFile.allCases.compactMap { file in
            loadSection(for: file)
        }

        guard !sections.isEmpty else {
            return nil
        }

        return WorkspaceContext(sections: sections)
    }

    private func loadSection(for file: WorkspaceBootstrapFile) -> WorkspaceContextSection? {
        let fileURL: URL = rootURL.appendingPathComponent(file.fileName)
        guard fileManager.fileExists(atPath: fileURL.path) else {
            return nil
        }

        do {
            let content: String = try String(contentsOf: fileURL, encoding: .utf8)
            let trimmed: String = content.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !trimmed.isEmpty else {
                return nil
            }
            return WorkspaceContextSection(title: file.fileName, content: trimmed)
        } catch {
            Self.logger.warning("Failed to read workspace file: \(file.fileName, privacy: .public)")
            return nil
        }
    }
}
