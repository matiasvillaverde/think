import Foundation
@testable import ModelDownloader
import Testing

@Suite("ProgressThrottler Tests")
struct ProgressThrottlerTests {
    @Test("Always updates on 0% progress")
    func testAlwaysUpdatesOnZeroProgress() async {
        // Given
        let throttler: ProgressThrottler<UUID> = ProgressThrottler<UUID>(throttleInterval: 1.0)
        let modelId: UUID = UUID()

        // When
        let shouldUpdate: Bool = await throttler.shouldUpdate(id: modelId, progress: 0.0)

        // Then
        #expect(shouldUpdate == true)
    }

    @Test("Always updates on 100% progress")
    func testAlwaysUpdatesOnCompleteProgress() async {
        // Given
        let throttler: ProgressThrottler<UUID> = ProgressThrottler<UUID>(throttleInterval: 1.0)
        let modelId: UUID = UUID()

        // When
        let shouldUpdate: Bool = await throttler.shouldUpdate(id: modelId, progress: 1.0)

        // Then
        #expect(shouldUpdate == true)
    }

    @Test("First update for an ID always goes through")
    func testFirstUpdateAlwaysGoesThrough() async {
        // Given
        let throttler: ProgressThrottler<UUID> = ProgressThrottler<UUID>()
        let modelId: UUID = UUID()

        // When
        let shouldUpdate: Bool = await throttler.shouldUpdate(id: modelId, progress: 0.5)

        // Then
        #expect(shouldUpdate == true)
    }

    @Test("Throttles updates within interval")
    func testThrottlesUpdatesWithinInterval() async {
        // Given
        let throttler: ProgressThrottler<UUID> = ProgressThrottler<UUID>(throttleInterval: 0.5)
        let modelId: UUID = UUID()

        // When - First update
        let firstUpdate: Bool = await throttler.shouldUpdate(id: modelId, progress: 0.3)

        // Immediate second update with small change (less than 1%)
        let secondUpdate: Bool = await throttler.shouldUpdate(id: modelId, progress: 0.305)

        // Then
        #expect(firstUpdate == true)
        #expect(secondUpdate == false)
    }

    @Test("Allows update after throttle interval")
    func testAllowsUpdateAfterInterval() async throws {
        // Given
        let throttler: ProgressThrottler<UUID> = ProgressThrottler<UUID>(throttleInterval: 0.1) // 100ms
        let modelId: UUID = UUID()

        // When - First update
        let firstUpdate: Bool = await throttler.shouldUpdate(id: modelId, progress: 0.3)

        // Wait for throttle: Any interval
        try await Task.sleep(nanoseconds: 150_000_000) // 150ms

        // Second update after interval
        let secondUpdate: Bool = await throttler.shouldUpdate(id: modelId, progress: 0.35)

        // Then
        #expect(firstUpdate == true)
        #expect(secondUpdate == true)
    }

    @Test("Allows update on significant progress change")
    func testAllowsUpdateOnSignificantChange() async {
        // Given
        let throttler: ProgressThrottler<UUID> = ProgressThrottler<UUID>(throttleInterval: 1.0)
        let modelId: UUID = UUID()

        // When - First update
        let firstUpdate: Bool = await throttler.shouldUpdate(id: modelId, progress: 0.3)

        // Immediate second update with significant change (>= 1%)
        let secondUpdate: Bool = await throttler.shouldUpdate(id: modelId, progress: 0.31)

        // Then
        #expect(firstUpdate == true)
        #expect(secondUpdate == true) // Should allow because change is >= 0.01
    }

    @Test("Tracks multiple IDs independently")
    func testTracksMultipleIdsIndependently() async {
        // Given
        let throttler: ProgressThrottler<UUID> = ProgressThrottler<UUID>(throttleInterval: 1.0)
        let modelId1: UUID = UUID()
        let modelId2: UUID = UUID()

        // When
        let update1: Bool = await throttler.shouldUpdate(id: modelId1, progress: 0.5)
        let update2: Bool = await throttler.shouldUpdate(id: modelId2, progress: 0.5)

        // Immediate updates for both with small change (less than 1%)
        let update1Again: Bool = await throttler.shouldUpdate(id: modelId1, progress: 0.505)
        let update2Again: Bool = await throttler.shouldUpdate(id: modelId2, progress: 0.505)

        // Then
        #expect(update1 == true)
        #expect(update2 == true)
        #expect(update1Again == false) // Throttled
        #expect(update2Again == false) // Throttled
    }

    @Test("Cleanup removes tracking data")
    func testCleanupRemovesTrackingData() async {
        // Given
        let throttler: ProgressThrottler<UUID> = ProgressThrottler<UUID>(throttleInterval: 1.0)
        let modelId: UUID = UUID()

        // When - First update
        _ = await throttler.shouldUpdate(id: modelId, progress: 0.5)

        // Cleanup
        await throttler.cleanup(id: modelId)

        // Update after cleanup should go through
        let updateAfterCleanup: Bool = await throttler.shouldUpdate(id: modelId, progress: 0.5)

        // Then
        #expect(updateAfterCleanup == true) // Should be treated as first update
    }

    @Test("Reset allows immediate update")
    func testResetAllowsImmediateUpdate() async {
        // Given
        let throttler: ProgressThrottler<UUID> = ProgressThrottler<UUID>(throttleInterval: 1.0)
        let modelId: UUID = UUID()

        // When - First update
        _ = await throttler.shouldUpdate(id: modelId, progress: 0.5)

        // Reset
        await throttler.reset(id: modelId)

        // Immediate update after reset
        let updateAfterReset: Bool = await throttler.shouldUpdate(id: modelId, progress: 0.51)

        // Then
        #expect(updateAfterReset == true)
    }
}
