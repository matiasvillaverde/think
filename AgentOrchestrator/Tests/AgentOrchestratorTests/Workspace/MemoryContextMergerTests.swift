import Abstractions
import Foundation
import Testing

@testable import AgentOrchestrator

@Suite("MemoryContextMerger Tests")
internal struct MemoryContextMergerTests {
    @Test("Merges memory contexts and deduplicates entries")
    internal func mergesAndDeduplicates() {
        let date: Date = Date(timeIntervalSince1970: 0)
        let fixtures: Fixtures = makeFixtures(date: date)

        let primary: MemoryContext = makeContext(
            soul: fixtures.soul,
            longTerm: [fixtures.longTerm],
            daily: []
        )
        let secondary: MemoryContext = makeContext(
            soul: nil,
            longTerm: [fixtures.longTerm],
            daily: [fixtures.daily]
        )

        let merged: MemoryContext? = MemoryContextMerger.merge(
            primary: primary,
            secondary: secondary
        )

        #expect(merged?.soul == fixtures.soul)
        #expect(merged?.longTermMemories.count == 1)
        #expect(merged?.recentDailyLogs.count == 1)
        #expect(merged?.recentDailyLogs.first?.content == "Daily content")
    }

    private struct Fixtures {
        let soul: MemoryData
        let longTerm: MemoryData
        let daily: MemoryData
    }

    private func makeFixtures(date: Date) -> Fixtures {
        let soul: MemoryData = makeMemoryData(
            type: .soul,
            content: "Soul content",
            date: nil,
            timestamp: date
        )
        let longTerm: MemoryData = makeMemoryData(
            type: .longTerm,
            content: "Long term content",
            date: nil,
            timestamp: date
        )
        let daily: MemoryData = makeMemoryData(
            type: .daily,
            content: "Daily content",
            date: date,
            timestamp: date
        )
        return Fixtures(soul: soul, longTerm: longTerm, daily: daily)
    }

    private func makeMemoryData(
        type: MemoryType,
        content: String,
        date: Date?,
        timestamp: Date
    ) -> MemoryData {
        MemoryData(
            id: UUID(),
            createdAt: timestamp,
            updatedAt: timestamp,
            type: type,
            content: content,
            date: date
        )
    }

    private func makeContext(
        soul: MemoryData?,
        longTerm: [MemoryData],
        daily: [MemoryData]
    ) -> MemoryContext {
        MemoryContext(
            soul: soul,
            longTermMemories: longTerm,
            recentDailyLogs: daily
        )
    }
}
