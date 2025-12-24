import Abstractions
import Foundation

/// Protocol for formatting memory context into prompt-ready strings
internal protocol MemoryFormatting {
    /// Formats the complete memory context for injection into the system prompt
    /// - Parameter memoryContext: The memory context to format
    /// - Returns: A formatted string ready for prompt injection
    func formatMemoryContext(_ memoryContext: MemoryContext) -> String
}

/// Default implementation of MemoryFormatting
extension MemoryFormatting {
    internal func formatMemoryContext(_ memoryContext: MemoryContext) -> String {
        guard !memoryContext.isEmpty else {
            return ""
        }

        var components: [String] = []

        // Format soul/identity section
        if let soul = memoryContext.soul {
            components.append(formatSoulSection(soul))
        }

        // Format long-term memories section
        if !memoryContext.longTermMemories.isEmpty {
            components.append(formatLongTermMemoriesSection(memoryContext.longTermMemories))
        }

        // Format recent daily logs section
        if !memoryContext.recentDailyLogs.isEmpty {
            components.append(formatDailyLogsSection(memoryContext.recentDailyLogs))
        }

        guard !components.isEmpty else {
            return ""
        }

        return "\n\n# Personal Memory\n\n" + components.joined(separator: "\n\n")
    }

    private func formatSoulSection(_ soul: MemoryData) -> String {
        """
        ## Identity & Core Values
        \(soul.content)
        """
    }

    private func formatLongTermMemoriesSection(_ memories: [MemoryData]) -> String {
        let formattedMemories: String = memories
            .map { "- \($0.content)" }
            .joined(separator: "\n")

        return """
        ## Long-term Memory
        \(formattedMemories)
        """
    }

    private func formatDailyLogsSection(_ logs: [MemoryData]) -> String {
        let dateFormatter: DateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy-MM-dd"

        let formattedLogs: String = logs
            .map { (log: MemoryData) -> String in
                let dateString: String = log.date
                    .map { dateFormatter.string(from: $0) } ?? "Unknown"
                return "### \(dateString)\n\(log.content)"
            }
            .joined(separator: "\n\n")

        return """
        ## Recent Context
        \(formattedLogs)
        """
    }
}
