import Abstractions
import Foundation

internal enum MemoryContextMerger {
    private static let dateFormatter: DateFormatter = {
        let formatter: DateFormatter = DateFormatter()
        formatter.calendar = Calendar(identifier: .iso8601)
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = TimeZone(secondsFromGMT: 0)
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter
    }()

    internal static func merge(
        primary: MemoryContext?,
        secondary: MemoryContext?
    ) -> MemoryContext? {
        guard primary != nil || secondary != nil else {
            return nil
        }

        let mergedSoul: MemoryData? = primary?.soul ?? secondary?.soul
        let mergedLongTerm: [MemoryData] = mergeEntries(
            primary?.longTermMemories ?? [],
            secondary?.longTermMemories ?? []
        )
        let mergedDaily: [MemoryData] = mergeEntries(
            primary?.recentDailyLogs ?? [],
            secondary?.recentDailyLogs ?? []
        )

        let merged: MemoryContext = MemoryContext(
            soul: mergedSoul,
            longTermMemories: mergedLongTerm,
            recentDailyLogs: mergedDaily
        )

        return merged.isEmpty ? nil : merged
    }

    private static func mergeEntries(
        _ first: [MemoryData],
        _ second: [MemoryData]
    ) -> [MemoryData] {
        var seen: Set<String> = Set()
        var merged: [MemoryData] = []

        for entry in first + second {
            let key: String = entryKey(entry)
            if seen.insert(key).inserted {
                merged.append(entry)
            }
        }

        return merged
    }

    private static func entryKey(_ entry: MemoryData) -> String {
        let dateKey: String = entry.date.map { dateFormatter.string(from: $0) } ?? "none"
        return "\(entry.type.rawValue)|\(dateKey)|\(entry.content)"
    }
}
