import Abstractions
import Foundation
import OSLog

/// Loads file-backed memory context from workspace files.
internal struct WorkspaceMemoryLoader: @unchecked Sendable {
    private static let logger: Logger = Logger(
        subsystem: AgentOrchestratorConfiguration.shared.logging.subsystem,
        category: "WorkspaceMemoryLoader"
    )

    private static let memoryFileName: String = "MEMORY.md"
    private static let memoryFolderName: String = "memory"

    private let rootURL: URL
    private let fileManager: FileManager
    private let calendar: Calendar
    private let now: () -> Date

    internal init(
        rootURL: URL,
        fileManager: FileManager = .default,
        calendar: Calendar = Calendar(identifier: .iso8601),
        now: @escaping () -> Date = Date.init
    ) {
        self.rootURL = rootURL
        self.fileManager = fileManager
        self.calendar = calendar
        self.now = now
    }

    internal func loadContext() -> MemoryContext? {
        let longTermMemories: [MemoryData] = loadLongTermMemories()
        let dailyLogs: [MemoryData] = loadDailyLogs()

        guard !longTermMemories.isEmpty || !dailyLogs.isEmpty else {
            return nil
        }

        return MemoryContext(
            soul: nil,
            longTermMemories: longTermMemories,
            recentDailyLogs: dailyLogs
        )
    }

    private func loadLongTermMemories() -> [MemoryData] {
        guard let content: FileContent = readFile(named: Self.memoryFileName) else {
            return []
        }

        return [
            MemoryData(
                id: UUID(),
                createdAt: content.timestamps.createdAt,
                updatedAt: content.timestamps.updatedAt,
                type: .longTerm,
                content: content.text
            )
        ]
    }

    private func loadDailyLogs() -> [MemoryData] {
        let dates: [Date] = recentDates()
        var entries: [MemoryData] = []

        for date in dates {
            guard let content: FileContent = readDailyFile(for: date) else {
                continue
            }

            let entry: MemoryData = MemoryData(
                id: UUID(),
                createdAt: content.timestamps.createdAt,
                updatedAt: content.timestamps.updatedAt,
                type: .daily,
                content: content.text,
                date: date
            )
            entries.append(entry)
        }

        return entries
    }

    private func recentDates() -> [Date] {
        let today: Date = calendar.startOfDay(for: now())
        let yesterday: Date? = calendar.date(byAdding: .day, value: -1, to: today)
        return [today, yesterday].compactMap(\.self)
    }

    private func readFile(named fileName: String) -> FileContent? {
        let fileURL: URL = rootURL.appendingPathComponent(fileName)
        return readFile(at: fileURL)
    }

    private func readDailyFile(for date: Date) -> FileContent? {
        let fileName: String = dailyFileName(for: date)
        let primaryURL: URL = rootURL
            .appendingPathComponent(Self.memoryFolderName)
            .appendingPathComponent(fileName)
        if let content: FileContent = readFile(at: primaryURL) {
            return content
        }

        let fallbackURL: URL = rootURL
            .appendingPathComponent(Self.memoryFolderName)
            .appendingPathComponent("daily")
            .appendingPathComponent(fileName)
        return readFile(at: fallbackURL)
    }

    private func dailyFileName(for date: Date) -> String {
        let formatter: DateFormatter = DateFormatter()
        formatter.calendar = calendar
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = TimeZone(secondsFromGMT: 0)
        formatter.dateFormat = "yyyy-MM-dd"
        return "\(formatter.string(from: date)).md"
    }

    private func readFile(at url: URL) -> FileContent? {
        guard fileManager.fileExists(atPath: url.path) else {
            return nil
        }

        do {
            let content: String = try String(contentsOf: url, encoding: .utf8)
            let trimmed: String = content.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !trimmed.isEmpty else {
                return nil
            }

            let timestamps: FileTimestamps = readTimestamps(for: url)
            return FileContent(text: trimmed, timestamps: timestamps)
        } catch {
            Self.logger.warning("Failed to read memory file: \(url.lastPathComponent, privacy: .public)")
            return nil
        }
    }

    private func readTimestamps(for url: URL) -> FileTimestamps {
        do {
            let attributes: [FileAttributeKey: Any] = try fileManager.attributesOfItem(atPath: url.path)
            let createdAt: Date = attributes[.creationDate] as? Date ?? now()
            let updatedAt: Date = attributes[.modificationDate] as? Date ?? createdAt
            return FileTimestamps(createdAt: createdAt, updatedAt: updatedAt)
        } catch {
            return FileTimestamps(createdAt: now(), updatedAt: now())
        }
    }

    private struct FileTimestamps {
        let createdAt: Date
        let updatedAt: Date
    }

    private struct FileContent {
        let text: String
        let timestamps: FileTimestamps
    }
}
